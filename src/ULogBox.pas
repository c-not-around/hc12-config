unit ULogBox;


{$reference System.Drawing.dll}
{$reference System.Windows.Forms.dll}

{$resource res\copy.png}
{$resource res\save.png}
{$resource res\clear.png}


uses System;
uses System.IO;
uses System.Drawing;
uses System.Windows.Forms;
uses UExtensions;


type
  LogBox = class(Control)
    {$region Fields}
    private _Log  : System.Windows.Forms.RichTextBox;
    private _Menu : System.Windows.Forms.ContextMenuStrip;
    {$endregion}
    
    {$region Override}
    protected procedure OnPaint(e: PaintEventArgs); override;
    begin
      inherited OnPaint(e);
      e.Graphics.DrawRectangle(Pens.Gray, new Rectangle(0, 0, Width-1, Height-1));
    end;
    
    protected procedure OnSizeChanged(e: EventArgs); override;
    begin
      inherited OnSizeChanged(e);
      _Log.Size := new System.Drawing.Size(Width - 2, Height - 2);
    end;
    
    protected procedure OnTabStopChanged(e: EventArgs); override;
    begin
      inherited OnTabStopChanged(e);
      _Log.TabStop := self.TabStop;
    end;
    {$endregion}
    
    {$region Ctors}
    public constructor ();
    begin
      var _MenuCopy   := new ToolStripMenuItem();
      _MenuCopy.Text  := 'Copy';
      _MenuCopy.Image := Resources.Image('copy.png');
      _MenuCopy.Click += MenuCopyClick;
      
      var _MenuSave   := new ToolStripMenuItem();
      _MenuSave.Text  := 'Save';
      _MenuSave.Image := Resources.Image('save.png');
      _MenuSave.Click += MenuSaveClick;
      
      var _MenuClear   := new ToolStripMenuItem();
      _MenuClear.Text  := 'Clear';
      _MenuClear.Image := Resources.Image('clear.png');
      _MenuClear.Click += MenuClearClick;
      
      _Menu := new System.Windows.Forms.ContextMenuStrip();
      _Menu.Items.AddRange(new ToolStripItem[] 
      (
        _MenuCopy,
        _MenuSave,
        _MenuClear
      ));
      
      _Log                  := new RichTextBox();
      _Log.Location         := new System.Drawing.Point(1, 1);
      _Log.Size             := new System.Drawing.Size(Width-2, Height-2);
      _Log.ReadOnly         := true;
      _Log.BackColor        := Color.White;
      _Log.BorderStyle      := BorderStyle.None;
      _Log.ScrollBars       := RichTextBoxScrollBars.ForcedVertical;
      _Log.Font             := new System.Drawing.Font('Consolas', 10, FontStyle.Regular, GraphicsUnit.Point);
      _Log.DetectUrls       := false;
      _Log.ContextMenuStrip := _Menu;
      Controls.Add(_Log);
    end;
    {$endregion}
    
    {$region Methods}
    private procedure MenuClearClick(sender: object; e: EventArgs) := _Log.Clear();
    
    private procedure MenuCopyClick(sender: object; e: EventArgs) := _Log.Copy();
    
    private procedure MenuSaveClick(sender: object; e: EventArgs);
    begin
      var dialog         := new SaveFileDialog();
      dialog.Filter      := 'Plain text file (*.txt)|*.txt|Log file (*.log)|*.log';
      dialog.FilterIndex := 1;
      dialog.FileName    := DateTime.Now.ToString('yyyyMMdd-HHmmss')+'.log';
      
      if dialog.ShowDialog() = DialogResult.OK then
        &File.WriteAllText(dialog.FileName, _Log.Text);
      
      dialog.Dispose();
    end;
    
    public procedure Append(text: string; color: System.Drawing.Color; newline: integer := 0);
    begin
      _Log.SelectionLength := 0;
      _Log.SelectionStart  := _Log.TextLength;
      _Log.SelectionColor  := color;
      _Log.AppendText(text);
    
      if newline > 0 then
        begin
          _Log.SelectionColor := System.Drawing.Color.Black;
          _Log.AppendText(#13#10 * newline);
        end;
    
      _Log.ScrollToCaret();
    end;
    {$endregion}
  end;


end.