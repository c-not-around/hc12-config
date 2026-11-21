unit UHc12;


uses System;
uses System.IO;
uses System.IO.Ports;
uses System.Threading;
uses System.Text.RegularExpressions;


type
  Hc12 = class(IDisposable)
    {$region Consts}
    private const _BaudRates = new integer[](1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200);
    private const _Powers    = new integer[](-1, 2, 5, 8, 11, 14, 17, 20);
    {$endregion}
    
    {$region Fields}
    private _Port         : SerialPort;
    private _Connected    : boolean;
    private _LastCommand  : string;
    private _LastResponse : string;
    {$endregion}
    
    {$region Routines}
    private function PortOpen(): boolean;
    begin
      if not _Port.IsOpen then
        try
          _Port.Open();
        except
          exit(false);
        end;
      
      result := _Port.IsOpen;
      
      if result then
        begin
          _Port.DtrEnable := false;
          Thread.Sleep(100);
          _Port.DtrEnable := true;
          Thread.Sleep(200);
        end;
    end;
    
    private function SendCommand(parameter: string; raw: boolean := false): string;
    begin
      _Port.DiscardOutBuffer();
      _Port.DiscardInBuffer();
      
      _LastCommand  := 'AT';
      _LastResponse := '';
      
      if not String.IsNullOrEmpty(parameter) then
        _LastCommand += '+' + parameter;
      
      try
        _Port.WriteLine(_LastCommand);
      except
        exit('IOERR');
      end;
      
      try
        _LastResponse := _Port.ReadLine();
      except
        exit('TIMEDOUT');
      end;
      
      if raw then
        exit(_LastResponse);
      
      if String.IsNullOrEmpty(parameter) then
        exit(_LastResponse = 'OK' ? 'OK' : 'ERROR');
      
      if _LastResponse.StartsWith('OK+') and (_LastResponse.Length > 3) then
        exit(_LastResponse.Substring(3));
      
      result := 'ERROR';
    end;
    
    private function SendSetCommand(parameter: string) := SendCommand(parameter) = parameter;
    
    private function CheckBaudrate(b: integer) := _BaudRates.Contains(b);
    
    private function CheckChannel(c: integer) := (c > 0) and (c < 128);
    
    private function CheckMode(m: integer) := (m > 0) and (m < 5);
    {$endregion}
    
    {$region Ctors}
    public constructor ();
    begin
      _Port             := new SerialPort();
      _Port.DataBits    := 8;
      _Port.Parity      := Parity.None;
      _Port.StopBits    := StopBits.One;
      _Port.NewLine     := #13#10;
      _Port.ReadTimeout := 500;
      
      _Connected    := false;
      _LastCommand  := '';
      _LastResponse := '';
    end;
    {$endregion}
    
    {$region Properties}
    public property PortName: string read (_Port.PortName) write _Port.PortName := value;
    
    public property PortBaudrate: integer read (_Port.BaudRate) write _Port.BaudRate := value;
    
    public property PortIsOpened: boolean read (_Port.IsOpen);
    
    public property IsConnected: boolean read (_Connected);
    
    public property IsPresence: boolean read (SendCommand('') = 'OK');
    
    public property Version: string read (SendCommand('V', true));
    
    public property Baudrate: integer read (GetBaudrate()) write SetBaudrate(value);
    
    public property Channel: integer read (GetChannel()) write SetChannel(value);
    
    public property Mode: integer read (GetMode()) write SetMode(value);
    
    public property Power: integer read (GetPower()) write SetPower(value);
    
    public property LastCommand:string read (_LastCommand);
    
    public property LastResponse:string read (_LastResponse);
    
    public property Baudrates[index: integer]:  integer read ((index > 0) and (index < _BaudRates.Length) ? _BaudRates[index] : 0);
    
    public property Powers[index: integer]:  integer read ((index > 0) and (index < _Powers.Length) ? _Powers[index] : 0);
    {$endregion}
    
    {$region Methods}
    public function Connect(): boolean;
    begin
      _Connected := PortOpen();
      
      if _Connected then
        _Connected := IsPresence;
      
      result := _Connected;
    end;
    
    public function Connect(port: string): boolean;
    begin
      _Port.PortName := port;
      result         := Connect();
    end;
    
    public function Connect(port: string; baud: integer): boolean;
    begin
      _Port.PortName := port;
      _Port.BaudRate := baud;
      result         := Connect();
    end;
    
    public procedure Disconnect();
    begin
      if _Port.IsOpen then
        begin
          _Port.DtrEnable := true;
          Thread.Sleep(200);
          _Port.Close();
        end;
      
      _Connected := false;
    end;
    
    public function FindPortBaudrate(): integer;
    begin
      _Connected := false;
      
      if PortOpen() then
        foreach var baud in _BaudRates do
          begin
            _Port.BaudRate := baud;
            
            if IsPresence then
              begin
                _Connected := true;
                exit(baud);
              end;
          end;
      
      result := 0;
    end;
    
    public function FindPortBaudrate(port: string): integer;
    begin
      _Port.PortName := port;
      result         := FindPortBaudrate();
    end;
    
    public function GetBaudrate(): integer;
    begin
      var response := SendCommand('RB');
      
      if (response.Length > 4) and response.StartsWith('B') then
        if Integer.TryParse(response.Substring(1), result) then
          if CheckBaudrate(result) then
            exit;
      
      result := 0;
    end;
    
    public function SetBaudrate(b: integer): boolean;
    begin
      if not CheckBaudrate(b) then
        raise new Exception($'Unsupported baudrate {b}');
      
      result := SendSetCommand($'B{b}');
    end;
    
    public function GetChannel(): integer;
    begin
      var response := SendCommand('RC');
      
      if (response.Length > 4) and response.StartsWith('RC') then
        if Integer.TryParse(response.Substring(2), result) then
          if CheckChannel(result) then
            exit;
      
      result := 0;
    end;
    
    public function SetChannel(c: integer): boolean;
    begin
      if not CheckChannel(c) then
        raise new Exception($'Unsupported channel {c}');
      
      result := SendSetCommand($'C{c:D3}');
    end;
    
    public function GetMode(): integer;
    begin
      var response := SendCommand('RF');
      
      if (response.Length > 2) and response.StartsWith('FU') then
        if Integer.TryParse(response.Substring(2), result) then
          if CheckMode(result) then
            exit;
      
      result := 0;
    end;
    
    public function SetMode(m: integer): boolean;
    begin
      if not CheckMode(m) then
        raise new Exception($'Unsupported mode {m}');
      
      result := SendSetCommand($'FU{m}');
    end;
    
    public function GetPower(): integer;
    begin
      var response := SendCommand('RP');
      
      result := 0;
      
      if (response.Length > 7) and response.StartsWith('RP:') then
        if Integer.TryParse(response.Substring(3, response.Length-6), result) then
          result := _Powers.IndexOf(result) + 1;
    end;
    
    public function SetPower(p: integer): boolean;
    begin
      if (p < 1) and (p > 8) then
        raise new Exception($'Unsupported power {p}');
      
      result := SendSetCommand($'P{p}');
    end;
    
    public function SetSerialSettings(settings: string): boolean;
    begin
      if not Regex.IsMatch(settings, '(7|8|9)(N|O|E)(1\.5|2|1)') then
        raise new Exception($'Unsupported serial settings {settings}');
      
      result := SendSetCommand($'U{settings}');
    end;
    
    public function SetSleepMode() := SendSetCommand('SLEEP');
    
    public function SetDefault() := SendSetCommand('DEFAULT');
    
    public procedure Dispose();
    begin
      Disconnect();
      _Port.Dispose();
      _Port := nil;
    end;
    {$endregion}
  end;


end.