unit UMainForm;


{$reference System.Drawing.dll}
{$reference System.Windows.Forms.dll}

{$resource res\icon.ico}
{$resource res\refresh.png}
{$resource res\connect.png}
{$resource res\disconnect.png}


uses System;
uses System.Threading;
uses System.IO;
uses System.IO.Ports;
uses System.Drawing;
uses System.Windows.Forms;
uses UExtensions;
uses ULogBox;
uses UHc12;


type
  MainForm = class(Form)
    {$region Fields}
    private _PortBox        : System.Windows.Forms.GroupBox;
    private _PortSelect     : System.Windows.Forms.ComboBox;
    private _PortsUpdate    : System.Windows.Forms.Button;
    private _PortBaud       : System.Windows.Forms.ComboBox;
    private _PortConnect    : System.Windows.Forms.Button;
    private _DeviceBox      : System.Windows.Forms.GroupBox;
    private _DeviceBaud     : System.Windows.Forms.ComboBox;
    private _DeviceUart     : System.Windows.Forms.ComboBox;
    private _DeviceChannel  : System.Windows.Forms.NumericUpDown;
    private _DeviceMode     : System.Windows.Forms.ComboBox;
    private _DevicePower    : System.Windows.Forms.ComboBox;
    private _DeviceRead     : System.Windows.Forms.Button;
    private _DeviceWrite    : System.Windows.Forms.Button;
    private _DeviceDefault  : System.Windows.Forms.Button;
    private _DeviceSleep    : System.Windows.Forms.Button;
    private _Log            : LogBox;
    private _Device         : Hc12;
    {$endregion}
    
    {$region Override}
    protected procedure OnFormClosing(e: FormClosingEventArgs); override;
    begin
      if _Device <> nil then
        _Device.Dispose();
      
      inherited OnFormClosing(e);
    end;
    
    protected procedure OnLoad(e: EventArgs); override;
    begin
      inherited OnLoad(e);
      
      var _ImageList := new System.Windows.Forms.ImageList();
      _ImageList.ColorDepth := System.Windows.Forms.ColorDepth.Depth32Bit;
      _ImageList.ImageSize  := new System.Drawing.Size(16, 16);
      _ImageList.Images.Add('connect', Resources.Image('connect.png'));
      _ImageList.Images.Add('disconnect', Resources.Image('disconnect.png'));
      _PortConnect.ImageList := _ImageList;
      _PortConnect.ImageKey  := 'connect';
      
      _PortBaud.Items.AddRange(new object[]('Auto', '1200', '2400', '4800', '9600', '19200', '38400', '57600', '115200'));
      _PortBaud.SelectedIndex := 4;
      _DeviceBaud.Items.AddRange(new object[](1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200));
      _DeviceUart.Items.AddRange(new object[]
        (
          '8N1', '8N2', '8N1.5',
          '8O1', '8O2', '8O1.5',
          '8E1', '8E2', '8E1.5'
        )
      );
      _DeviceMode.Items.AddRange(new object[]('FU1', 'FU2', 'FU3', 'FU4'));
      _DevicePower.Items.AddRange(new object[]('-1dBm', '2dBm', '5dBm', '8dBm', '11dBm', '14dBm', '17dBm', '20dBm'));
      
      _DeviceWrite.Enabled := false;
      _DeviceBox.Enabled   := false;
      
      PortsUpdate();
    end;
    {$endregion}
    
    {$region Routines}
    private procedure PortsUpdate(prev: string := '');
    begin
      _PortConnect.Enabled := false;
      
      _PortSelect.Items.Clear();
      foreach var port in SerialPort.GetPortNames() do
        _PortSelect.Items.Add(port);
      
      if not String.IsNullOrEmpty(prev) and _PortSelect.Items.Contains(prev) then
        _PortSelect.SelectedItem := prev
      else if _PortSelect.Items.Count > 0 then
        _PortSelect.SelectedIndex := 0;
    end;
    
    private procedure DeviceConnect();
    begin
      _PortBox.Enabled := false;
      
      _Device.Disconnect();
      _Device.PortName := _PortSelect.SelectedItem.ToString();
      
      var baud := _PortBaud.SelectedItem.ToString();
      
      if baud = 'Auto' then
        begin
          _Log.Append('module ', Color.Black);
          _Log.Append('search', Color.Blue);
          _Log.Append(' ... ', Color.Black);
          
          var b := _Device.FindPortBaudrate();
          
          if b > 0 then
            begin
              baud := b.ToString();
              
              _PortBaud.SelectedItem := baud;
              
              _Log.Append('ok', Color.Green, 1);
              _Log.Append('module ', Color.Black);
              _Log.Append('baudrate', Color.Blue);
              _Log.Append(' is ', Color.Black);
              _Log.Append(baud, Color.DarkMagenta, 1);
            end
          else
            _Log.Append('not found', Color.Red, 1);
        end
      else
        begin
          _Log.Append('connect', Color.Blue);
          _Log.Append(' ... ', Color.Black);
          
          _Device.PortBaudrate := Convert.ToInt32(baud);
          
          if _Device.Connect() then
            _Log.Append('ok', Color.Green, 1)
          else
            _Log.Append('fail', Color.Red, 1);
        end;
      
      if _Device.IsConnected then
        begin
          _PortSelect.Enabled   := false;
          _PortsUpdate.Enabled  := false;
          _PortBaud.Enabled     := false;
          _PortConnect.ImageKey := 'disconnect';
          _DeviceBox.Enabled    := true;
          
          _Log.Append('module ', Color.Black);
          _Log.Append('version', Color.Blue);
          _Log.Append(': "', Color.Black);
          _Log.Append(_Device.Version, Color.DarkMagenta);
          _Log.Append('"', Color.Black, 1);
        end;
      
      _PortBox.Enabled := true;
      _PortBox.Refresh();
    end;
    
    private procedure DeviceDisconnect();
    begin
      _PortBox.Enabled   := false;
      _DeviceBox.Enabled := false;
      
      _Log.Append('disconnect', Color.Blue);
      _Log.Append(' ... ', Color.Black);
      _Device.Disconnect();
      _Log.Append('ok', Color.Green, 1);
      
      PortsUpdate(_Device.PortName);
      
      _PortBox.Enabled      := true;
      _PortSelect.Enabled   := true;
      _PortsUpdate.Enabled  := true;
      _PortBaud.Enabled     := true;
      _PortConnect.ImageKey := 'connect';
    end;
    
    private procedure DeviceAccessLockInterface(&lock: boolean);
    begin
      _PortBox.Enabled   := not &lock;
      _DeviceBox.Enabled := not &lock;
      _DeviceBox.Refresh();
    end;
    
    private procedure DeviceAccessLog(success: boolean; text: string; fail: string := 'none');
    begin
      _Log.Append($'"{_Device.LastCommand}"', Color.Blue);
      _Log.Append(' -> ', Color.Black);
      _Log.Append($'"{_Device.LastResponse}"', Color.DarkMagenta);
      _Log.Append(' (', Color.Black);
      _Log.Append(success ? text : fail, success ? Color.Green : Color.Red);
      _Log.Append(')', Color.Black, 1);
    end;
    {$endregion}
    
    {$region Handlers}
    private procedure PortSelectSelectedIndexChanged(sender: object; e: EventArgs) := _PortConnect.Enabled := _PortSelect.SelectedIndex > -1;
    
    private procedure PortsUpdateClick(sender: object; e: EventArgs) := PortsUpdate();
    
    private procedure PortConnectClick(sender: object; e: EventArgs);
    begin
      if _Device.IsConnected then
        DeviceDisconnect()
      else
        DeviceConnect();
    end;
    
    private procedure DeviceSettingSelectedIndexChanged(sender: object; e: EventArgs);
    begin
      _DeviceWrite.Enabled := (_DeviceBaud.SelectedIndex > -1) and
                              (_DeviceUart.SelectedIndex > -1) and
                              (_DeviceMode.SelectedIndex > -1) and
                              (_DevicePower.SelectedIndex > -1);
    end;
    
    private procedure DeviceReadClick(sender: object; e: EventArgs);
    begin
      DeviceAccessLockInterface(true);
      
      _Log.Append('settings ', Color.Black);
      _Log.Append('read', Color.Blue, 1);
      
      var baud := _Device.Baudrate;
      _DeviceBaud.SelectedItem := baud > 0 ? baud : nil;
      DeviceAccessLog(baud > 0, $'{baud}bps');
      
      _DeviceUart.SelectedItem := '8N1';
      
      var channel := _Device.Channel;
      _DeviceChannel.Value := channel;
      DeviceAccessLog(channel > 0, $'channel {channel}');
      
      var mode := _Device.Mode;
      _DeviceMode.SelectedIndex := mode - 1;
      DeviceAccessLog(mode > 0, $'FU{mode}');
      
      var power := _Device.Power;
      _DevicePower.SelectedIndex := power - 1;
      DeviceAccessLog(power > 0, $'{_Device.Powers[power-1]}dBm');
      
      DeviceAccessLockInterface(false);
    end;
    
    private procedure DeviceWriteClick(sender: object; e: EventArgs);
    begin
      DeviceAccessLockInterface(true);
      
      _Log.Append('settings ', Color.Black);
      _Log.Append('write', Color.Blue, 1);
      
      var status := _Device.SetBaudrate(Convert.ToInt32(_DeviceBaud.SelectedItem));
      DeviceAccessLog(status, 'ok', 'fail');
      
      status := _Device.SetSerialSettings(_DeviceUart.SelectedItem.ToString());
      DeviceAccessLog(status, 'ok', 'fail');
      
      status := _Device.SetChannel(Convert.ToInt32(_DeviceChannel.Value));
      DeviceAccessLog(status, 'ok', 'fail');
      
      status := _Device.SetMode(_DeviceMode.SelectedIndex+1);
      DeviceAccessLog(status, 'ok', 'fail');
      
      status := _Device.SetPower(_DevicePower.SelectedIndex+1);
      DeviceAccessLog(status, 'ok', 'fail');
      
      DeviceAccessLockInterface(false);
    end;
    
    private procedure DeviceDefaultClick(sender: object; e: EventArgs);
    begin
      DeviceAccessLockInterface(true);
      
      _Log.Append('settings set to ', Color.Black);
      _Log.Append('default', Color.Blue, 1);
      
      var status := _Device.SetDefault();
      DeviceAccessLog(status, 'ok', 'fail');
      
      DeviceAccessLockInterface(false);
    end;
    
    private procedure DeviceSleepClick(sender: object; e: EventArgs);
    begin
      DeviceAccessLockInterface(true);
      
      _Log.Append('module turn to ', Color.Black);
      _Log.Append('sleep', Color.Blue, 1);
      
      var status := _Device.SetSleepMode();
      DeviceAccessLog(status, 'ok', 'fail');
      
      DeviceAccessLockInterface(false);
    end;
    {$endregion}
    
    {$region Ctors}
    public constructor ();
    begin
      {$region MainForm}
      MinimumSize   := new System.Drawing.Size(500, 395);
      Size          := new System.Drawing.Size(500, 395);
      Text          := 'HC-12 Config';
      Icon          := Resources.Icon('icon.ico');
      StartPosition := FormStartPosition.CenterScreen;
      {$endregion}
      
      {$region Port}
      _PortBox          := new System.Windows.Forms.GroupBox();
      _PortBox.Size     := new System.Drawing.Size(125, 101);
      _PortBox.Location := new System.Drawing.Point(5, 5);
      _PortBox.Text     := 'Link';
      Controls.Add(_PortBox);
      
      var _PortSelectDesc      := new System.Windows.Forms.Label();
      _PortSelectDesc.Size     := new System.Drawing.Size(89, 13);
      _PortSelectDesc.Location := new System.Drawing.Point(5, 20);
      _PortSelectDesc.Text     := 'Port:';
      _PortBox.Controls.Add(_PortSelectDesc);
      
      _PortSelect                      := new ComboBox();
      _PortSelect.Size                 := new System.Drawing.Size(_PortSelectDesc.Width, 20);
      _PortSelect.Location             := new System.Drawing.Point(_PortSelectDesc.Left, _PortSelectDesc.Top+_PortSelectDesc.Height);
      _PortSelect.DropDownStyle        := ComboBoxStyle.DropDownList;
      _PortSelect.TabStop              := false;
      _PortSelect.SelectedIndexChanged += PortSelectSelectedIndexChanged;
      _PortBox.Controls.Add(_PortSelect);
      
      _PortsUpdate          := new System.Windows.Forms.Button();
      _PortsUpdate.Size     := new System.Drawing.Size(24, 23);
      _PortsUpdate.Location := new System.Drawing.Point(_PortSelect.Left+_PortSelect.Width+2, _PortSelect.Top-1);
      _PortsUpdate.Image    := Resources.Image('refresh.png');
      _PortsUpdate.TabStop  := false;
      _PortsUpdate.Click    += PortsUpdateClick;
      _PortBox.Controls.Add(_PortsUpdate);
      
      var _PortBaudDesc      := new System.Windows.Forms.Label();
      _PortBaudDesc.Size     := new System.Drawing.Size(_PortSelectDesc.Width, _PortSelectDesc.Height);
      _PortBaudDesc.Location := new System.Drawing.Point(_PortSelectDesc.Left, _PortSelect.Top+_PortSelect.Height+5);
      _PortBaudDesc.Text     := 'Baudrate:';
      _PortBox.Controls.Add(_PortBaudDesc);
      
      _PortBaud               := new System.Windows.Forms.ComboBox();
      _PortBaud.Size          := new System.Drawing.Size(_PortBaudDesc.Width, 20);
      _PortBaud.Location      := new System.Drawing.Point(_PortBaudDesc.Left, _PortBaudDesc.Top+_PortBaudDesc.Height);
      _PortBaud.DropDownStyle := ComboBoxStyle.DropDownList;
      _PortBaud.TabStop       := false;
      _PortBox.Controls.Add(_PortBaud);
      
      _PortConnect          := new System.Windows.Forms.Button();
      _PortConnect.Size     := new System.Drawing.Size(_PortsUpdate.Width, _PortsUpdate.Height);
      _PortConnect.Location := new System.Drawing.Point(_PortBaud.Left+_PortBaud.Width+2, _PortBaud.Top-1);
      _PortConnect.TabStop  := false;
      _PortConnect.Click    += PortConnectClick;
      _PortBox.Controls.Add(_PortConnect);
      {$endregion}
      
      {$region Device}
      _DeviceBox          := new System.Windows.Forms.GroupBox();
      _DeviceBox.Size     := new System.Drawing.Size(_PortBox.Width, 237);
      _DeviceBox.Location := new System.Drawing.Point(_PortBox.Left, _PortBox.Top+_PortBox.Height+5);
      _DeviceBox.Text     := 'Device';
      Controls.Add(_DeviceBox);
      
      var _DeviceBaudDesc      := new System.Windows.Forms.Label();
      _DeviceBaudDesc.Size     := new System.Drawing.Size(115, _PortSelectDesc.Height);
      _DeviceBaudDesc.Location := new System.Drawing.Point(5, 20);
      _DeviceBaudDesc.Text     := 'UART:';
      _DeviceBox.Controls.Add(_DeviceBaudDesc);
      
      _DeviceBaud                      := new System.Windows.Forms.ComboBox();
      _DeviceBaud.Size                 := new System.Drawing.Size(60, 20);
      _DeviceBaud.Location             := new System.Drawing.Point(_DeviceBaudDesc.Left, _DeviceBaudDesc.Top+_DeviceBaudDesc.Height);
      _DeviceBaud.DropDownStyle        := ComboBoxStyle.DropDownList;
      _DeviceBaud.TabStop              := false;
      _DeviceBaud.SelectedIndexChanged += DeviceSettingSelectedIndexChanged;
      _DeviceBox.Controls.Add(_DeviceBaud);
      
      _DeviceUart                      := new System.Windows.Forms.ComboBox();
      _DeviceUart.Size                 := new System.Drawing.Size(54, _DeviceBaud.Height);
      _DeviceUart.Location             := new System.Drawing.Point(_DeviceBaud.Left+_DeviceBaud.Width+1, _DeviceBaud.Top);
      _DeviceUart.DropDownStyle        := ComboBoxStyle.DropDownList;
      _DeviceUart.TabStop              := false;
      _DeviceUart.SelectedIndexChanged += DeviceSettingSelectedIndexChanged;
      _DeviceBox.Controls.Add(_DeviceUart);
      
      var _DeviceChannelDesc      := new System.Windows.Forms.Label();
      _DeviceChannelDesc.Size     := new System.Drawing.Size(_DeviceBaudDesc.Width, _PortSelectDesc.Height);
      _DeviceChannelDesc.Location := new System.Drawing.Point(_DeviceBaudDesc.Left, _DeviceBaud.Top+_DeviceBaud.Height+5);
      _DeviceChannelDesc.Text     := 'Channel:';
      _DeviceBox.Controls.Add(_DeviceChannelDesc);
      
      _DeviceChannel           := new System.Windows.Forms.NumericUpDown();
      _DeviceChannel.Size      := new System.Drawing.Size(_DeviceChannelDesc.Width, _DeviceBaud.Height);
      _DeviceChannel.Location  := new System.Drawing.Point(_DeviceChannelDesc.Left, _DeviceChannelDesc.Top+_DeviceChannelDesc.Height);
      _DeviceChannel.Minimum   := 1;
      _DeviceChannel.Maximum   := 127;
      _DeviceChannel.TextAlign := HorizontalAlignment.Center;
      _DeviceChannel.TabStop   := false;
      _DeviceBox.Controls.Add(_DeviceChannel);
      
      var _DeviceModeDesc      := new System.Windows.Forms.Label();
      _DeviceModeDesc.Size     := new System.Drawing.Size(_DeviceChannelDesc.Width, _DeviceChannelDesc.Height);
      _DeviceModeDesc.Location := new System.Drawing.Point(_DeviceChannelDesc.Left, _DeviceChannel.Top+_DeviceChannel.Height+5);
      _DeviceModeDesc.Text     := 'Mode:';
      _DeviceBox.Controls.Add(_DeviceModeDesc);
      
      _DeviceMode                      := new System.Windows.Forms.ComboBox();
      _DeviceMode.Size                 := new System.Drawing.Size(_DeviceModeDesc.Width, _DeviceModeDesc.Height);
      _DeviceMode.Location             := new System.Drawing.Point(_DeviceModeDesc.Left, _DeviceModeDesc.Top+_DeviceModeDesc.Height);
      _DeviceMode.DropDownStyle        := ComboBoxStyle.DropDownList;
      _DeviceMode.TabStop              := false;
      _DeviceMode.SelectedIndexChanged += DeviceSettingSelectedIndexChanged;
      _DeviceBox.Controls.Add(_DeviceMode);
      
      var _DevicePowerDesc      := new System.Windows.Forms.Label();
      _DevicePowerDesc.Size     := new System.Drawing.Size(_DeviceModeDesc.Width, _DeviceModeDesc.Height);
      _DevicePowerDesc.Location := new System.Drawing.Point(_DeviceModeDesc.Left, _DeviceMode.Top+_DeviceMode.Height+5);
      _DevicePowerDesc.Text     := 'Power:';
      _DeviceBox.Controls.Add(_DevicePowerDesc);
      
      _DevicePower                      := new System.Windows.Forms.ComboBox();
      _DevicePower.Size                 := new System.Drawing.Size(_DevicePowerDesc.Width, _DevicePowerDesc.Height);
      _DevicePower.Location             := new System.Drawing.Point(_DevicePowerDesc.Left, _DevicePowerDesc.Top+_DevicePowerDesc.Height);
      _DevicePower.DropDownStyle        := ComboBoxStyle.DropDownList;
      _DevicePower.TabStop              := false;
      _DevicePower.SelectedIndexChanged += DeviceSettingSelectedIndexChanged;
      _DeviceBox.Controls.Add(_DevicePower);
      
      _DeviceRead          := new System.Windows.Forms.Button();
      _DeviceRead.Size     := new System.Drawing.Size(56, 24);
      _DeviceRead.Location := new System.Drawing.Point(_DevicePower.Left-1, _DevicePower.Top+_DevicePower.Height+7);
      _DeviceRead.TabStop  := false;
      _DeviceRead.Text     := 'Read';
      _DeviceRead.Click    += DeviceReadClick;
      _DeviceBox.Controls.Add(_DeviceRead);
      
      _DeviceWrite          := new System.Windows.Forms.Button();
      _DeviceWrite.Size     := new System.Drawing.Size(_DeviceRead.Width, _DeviceRead.Height);
      _DeviceWrite.Location := new System.Drawing.Point(_DeviceRead.Left+_DeviceRead.Width+5, _DeviceRead.Top);
      _DeviceWrite.TabStop  := false;
      _DeviceWrite.Text     := 'Write';
      _DeviceWrite.Click    += DeviceWriteClick;
      _DeviceBox.Controls.Add(_DeviceWrite);
      
      _DeviceDefault          := new System.Windows.Forms.Button();
      _DeviceDefault.Size     := new System.Drawing.Size(_DeviceRead.Width, _DeviceRead.Height);
      _DeviceDefault.Location := new System.Drawing.Point(_DeviceRead.Left, _DeviceRead.Top+_DeviceRead.Height+5);
      _DeviceDefault.TabStop  := false;
      _DeviceDefault.Text     := 'Default';
      _DeviceDefault.Click    += DeviceDefaultClick;
      _DeviceBox.Controls.Add(_DeviceDefault);
      
      _DeviceSleep          := new System.Windows.Forms.Button();
      _DeviceSleep.Size     := new System.Drawing.Size(_DeviceRead.Width, _DeviceRead.Height);
      _DeviceSleep.Location := new System.Drawing.Point(_DeviceDefault.Left+_DeviceDefault.Width+5, _DeviceDefault.Top);
      _DeviceSleep.TabStop  := false;
      _DeviceSleep.Text     := 'Sleep';
      _DeviceSleep.Click    += DeviceSleepClick;
      _DeviceBox.Controls.Add(_DeviceSleep);
      {$endregion}
    
      {$region Log}
      _Log          := new LogBox();
      _Log.Size     := new System.Drawing.Size(342, 336);
      _Log.Location := new System.Drawing.Point(_PortBox.Left+_PortBox.Width+5, _PortBox.Top+6);
      _Log.Anchor   := AnchorStyles.Left or AnchorStyles.Top or AnchorStyles.Right or AnchorStyles.Bottom;
      _Log.TabStop  := false;
      Controls.Add(_Log);
      {$endregion}
      
      {$region Device}
      _Device := new Hc12();
      {$endregion}
    end;
    {$endregion}
  end;


end.