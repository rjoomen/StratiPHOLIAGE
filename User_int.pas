unit User_int;

{$MODE objfpc}{$H+}

// Main user interface

// Copyright (c), 2004-2006, Roelof Oomen

interface

uses
  Classes, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Calc;

type

  { TForm1 }

  TForm1 = class(TForm)
    BS1Edit: TLabeledEdit;
    BS2Edit: TLabeledEdit;
    BS3Edit: TLabeledEdit;
    BL1Edit: TLabeledEdit;
    BL2Edit: TLabeledEdit;
    BL3Edit: TLabeledEdit;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    Label1: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label2: TLabel;
    Label5: TLabel;
    Label12: TLabel;
    Edit1: TEdit;
    FileOpenButton: TButton;
    DataMemo: TMemo;
    Edit2: TEdit;
    SubplotCountEdit: TEdit;
    IndCountEdit: TEdit;
    SpeciesCountEdit: TEdit;
    PlotNameEdit: TEdit;
    OptionSheet: TTabSheet;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Bevel1: TBevel;
    Bevel2: TBevel;
    Bevel3: TBevel;
    Label13: TLabel;
    Label14: TLabel;
    Bevel4: TBevel;
    Label15: TLabel;
    Bevel6: TBevel;
    RunButton: TButton;
    SpeciesListBox: TListBox;
    SubplotListBox: TListBox;
    IndListBox: TListBox;
    CalcAlphaCheckBox: TCheckBox;
    File_kCheckBox: TCheckBox;
    DateEdit: TEdit;
    DateUpDown: TUpDown;
    OvercastCheckBox: TCheckBox;
    I_difEdit: TEdit;
    I_difUpDown: TUpDown;
    GDayUpDown: TUpDown;
    GDayEdit: TLabeledEdit;
    f_RdUpDown: TUpDown;
    ProgressBar1: TProgressBar;
    DisplayButton: TButton;
    GLayerEdit: TLabeledEdit;
    GLayerUpDown: TUpDown;
    TabSheet3: TTabSheet;
    ResultMemo: TMemo;
    TabSheet4: TTabSheet;
    Label9: TLabel;
    SaveButton: TButton;
    LightAbsOutCheckBox: TCheckBox;
    PhotosynthOutCheckBox: TCheckBox;
    LayersOutCheckBox: TCheckBox;
    Label19: TLabel;
    Bevel7: TBevel;
    Bevel8: TBevel;
    Bevel9: TBevel;
    RunMTButton: TButton;
    Label26: TLabel;
    Label27: TLabel;
    Bevel10: TBevel;
    ThreadNoUpDown: TUpDown;
    ThreadNoEdit: TEdit;
    Label28: TLabel;
    RuntimeEdit: TEdit;
    Label29: TLabel;
    Label30: TLabel;
    Label31: TLabel;
    Label32: TLabel;
    Label33: TLabel;
    f_RdEdit: TEdit;
    Label44: TLabel;
    AngleOptsCheckBox: TCheckBox;
    Panel1: TPanel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    Label40: TLabel;
    Label41: TLabel;
    BS3UpDown: TUpDown;
    BS2UpDown: TUpDown;
    BS1UpDown: TUpDown;
    Bevel11: TBevel;
    Label37: TLabel;
    Label38: TLabel;
    Label39: TLabel;
    Label42: TLabel;
    Label43: TLabel;
    BL3UpDown: TUpDown;
    BL2UpDown: TUpDown;
    BL1UpDown: TUpDown;
    procedure ExitButtonClick(Sender: TObject);
    procedure FileOpenButtonClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure IndListBoxClick(Sender: TObject);
    procedure SubplotListBoxClick(Sender: TObject);
    procedure SpeciesListBoxClick(Sender: TObject);
    procedure RunButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure LightAbsOutCheckBoxClick(Sender: TObject);
    procedure OvercastCheckBoxClick(Sender: TObject);
    procedure f_RdUpDownClick(Sender: TObject);
    procedure DisplayButtonClick(Sender: TObject);
    procedure RunMTButtonClick(Sender: TObject);
    procedure f_RdEditChange(Sender: TObject);
    procedure AngleOptsCheckBoxClick(Sender: TObject);
  private
    { Private declarations }
    procedure SetOptionsPlotM;
    procedure ResetOptions;
  public
    { Public declarations }
  end;

  TVersion = class
    function Getversion: string;
  end;

  TCalcThread = class(TThread)
  private
    { Private declarations }
  protected
    ind: integer;
    date: integer;
    calculate: TCalc;
    procedure sync;
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: boolean; i, d: integer); overload;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  Controls, Contnrs, LazLogger, SysUtils, strutils,
  fileinfo, // fileinfo reads exe resources as long as you register the appropriate units
  winpeimagereader, {need this for reading exe info}
  elfreader, {needed for reading ELF executables}
  machoreader, {needed for reading MACH-O executables}
  Data_defs, Data_RW, Uhashtable;

var
  PlotM: TPlot; // Main Data Structure

  WorkBook: TPlotWB; // For reading the data
  Output: TWriteExcel; // For saving the output
  Calculate: TCalc; // For calculating

  ThreadList: TObjectList;
  ThrSemaphore: Pointer;

  version: string;

function TVersion.getVersion: string;
var
  FileVerInfo: TFileVersionInfo;
  version: string;
begin
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.FileName := ParamStr(0);
    FileVerInfo.ReadFileInfo;
    version := FileVerInfo.VersionStrings.Values['FileVersion'];
    // Cut off build number
    version := LeftStr(version, RPos('.', version) - 1);
  finally
    FreeAndNil(FileVerInfo);
  end;
  Result := version;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  ProgVersion: Tversion;
begin
  Form1.PageControl1.ActivePageIndex := 0; // Select first TabSheet
  DataMemo.DoubleBuffered := True;
  Application.HintHidePause := 15000; // Make hints (tooltips) visible for 15s

  ProgVersion := TVersion.Create; // Retrieve project version information
  version := ProgVersion.GetVersion;
  FreeAndNil(ProgVersion);

  Form1.Caption := Form1.Caption + ' v.' + version;

  // These hints are set here, because Delphi's Object Inspector does not support multiline hints
  File_kCheckBox.Hint := 'If checked, diffuse light extinction is' + #13 + 'calculated using the vegetation k value' +
    #13 + 'specified in the data file (if available).' + #13 + 'If unchecked, the vegetation''s extinction' +
    #13 + 'is entirely calculated, depending on LAI';

  CalcAlphaCheckBox.Hint := 'If checked, the Alpha of the Individual is a function' + #13 +
    'of Chlorophyl-content, otherwise Alpha is set to' + #13 + 'the plot Alpha value';

  OvercastCheckBox.Hint := 'On an overcast day, the only incoming radiation is diffuse:' + #13 +
    'A constant Idif light intensity above the vegetation and an I0dir of zero.';
end;

procedure TForm1.FileOpenButtonClick(Sender: TObject);
var
  i: integer;
begin
  OpenDialog1.Filter :=
    'Spreadsheet files (*.xls;*.xlsx;*.ods)|*.xls;*.XLS;*.xlsx;*.XLSX;*.ods;*.ODS|All files|*.*';
  if opendialog1.Execute then
    Edit1.Text := ExtractFileName(OpenDialog1.FileName)
  else
    exit;

  WorkBook := TPlotWB.Create;

  if FileExists(OpenDialog1.FileName) then // Check if file exists
    try { Finally statement below makes sure the cursor get back to normal }
      Screen.Cursor := crHourglass;
      FileOpenButton.Enabled := False;
      DataMemo.Clear;

      SpeciesListBox.Clear;
      SubplotListBox.Clear;
      IndListBox.Clear;

      ResultMemo.Clear;

      FreeAndNil(PlotM); // Make sure all data is cleared, in case data was read in before
      PlotM := TPlot.Create;
      WorkBook.PlotWB := PlotM;
      WorkBook.filename := OpenDialog1.FileName;
      i := WorkBook.WBRead;
      if i = 0 then
      begin
        OptionSheet.Enabled := True;
        ResetOptions;

        PlotNameEdit.Text := PlotM.Name;
        SpeciesCountEdit.Text := IntToStr(PlotM.Species.Count);
        SubplotCountEdit.Text := IntToStr(PlotM.SubPlot.Count);
        IndCountEdit.Text := IntToStr(PlotM.Individual.Count);

        if IndListBox.Count > 0 then // Select first Individual
        begin
          IndListBox.ItemIndex := 0;
          i := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).subplot.hash;
          SubplotListBox.ItemIndex := PlotM.HTSubPlot.Getindex(i);
          i := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).species.hash;
          SpeciesListBox.ItemIndex := PlotM.HTSpecies.Getindex(i);
        end;

      end
      else
        Edit1.Text := '--error ' + IntToStr(i) + ' reading file: select another file--';

    finally
      FileOpenButton.Enabled := True;
      Screen.Cursor := crDefault;
    end
  else
    MessageDlg('File not found.', mtInformation, [mbOK], 0);
  FreeAndNil(Workbook);
end;

{
  Reset everything in the model options tab to defaults
}
procedure TForm1.ResetOptions;
begin
  File_kCheckBox.Checked := PlotM.k_veg_data;
  CalcAlphaCheckBox.Checked := not PlotM.alpha_const;
  I_difUpDown.Position := PlotM.I_overcast;
  OvercastCheckBox.Checked := PlotM.Overcast;
  DateUpDown.Position := PlotM.doy;
  f_RdEdit.Text := FloatToStr(f_Rd_def);
  // Default leaf angles
  BS1UpDown.Position := round(rad2deg(r15));
  BS2UpDown.Position := round(rad2deg(r45));
  BS3UpDown.Position := round(rad2deg(r75));
  BL1UpDown.Position := round(rad2deg(r15));
  BL2UpDown.Position := round(rad2deg(r45));
  BL3UpDown.Position := round(rad2deg(r75));
  // Integration steps
  GDayUpDown.Position:=8;
  GLayerUpDown.Position:=5;

  ProgressBar1.Position := 0; // Indicate not calculated
  RuntimeEdit.Text := '';
end;

{
  Initialise calculation with options from GUI

  Debug output to check that all GUI settings are applied correctly
}
procedure TForm1.SetOptionsPlotM;
var
  i: integer;
begin
  // Write options to Plot
  PlotM.k_veg_data := File_kCheckBox.Checked;
  PlotM.Alpha_const := not CalcAlphaCheckBox.Checked;
  PlotM.I_overcast := I_difUpDown.Position;
  PlotM.Overcast := OvercastCheckBox.Checked;
  PlotM.doy := DateUpDown.Position;

  DebugLn('k_veg_data: ' + BoolToStr(PlotM.k_veg_data));
  DebugLn('alpha_const: ' + BoolToStr(PlotM.alpha_const));
  DebugLn('I_overcast: ' + IntToStr(PlotM.I_overcast));
  DebugLn('Overcast: ' + BoolToStr(PlotM.Overcast));
  DebugLn('doy: ' + inttostr(PlotM.doy));

  // Apply Night Respiration Constant to all Species
  for i := 0 to PlotM.Species.Count - 1 do
  begin
    TSpecies(PlotM.Species[i]).f_Rd := f_RdUpDown.position / 100;

    if i = 0 then DebugLn('f_Rd: '+ FloatToStr(TSpecies(PlotM.Species[i]).f_Rd));
  end;

  // Apply sun angles to all individuals
  for i := 0 to PlotM.Individual.Count - 1 do
  begin
    TIndividual(PlotM.Individual[i]).Bs1 := deg2rad(BS1UpDown.Position);
    TIndividual(PlotM.Individual[i]).Bs2 := deg2rad(BS2UpDown.Position);
    TIndividual(PlotM.Individual[i]).Bs3 := deg2rad(BS3UpDown.Position);

    if i = 0 then
    begin
      DebugLn('BS1: '+ FloatToStr(round(rad2deg(TIndividual(PlotM.Individual[i]).Bs1))));
      DebugLn('BS2: '+ FloatToStr(round(rad2deg(TIndividual(PlotM.Individual[i]).Bs2))));
      DebugLn('BS3: '+ FloatToStr(round(rad2deg(TIndividual(PlotM.Individual[i]).Bs3))));
    end;
  end;
  // Apply sun angles to all subplots
  for i := 0 to PlotM.SubPlot.Count - 1 do
  begin
    TSubPlot(PlotM.Subplot[i]).Bs1 := deg2rad(BS1UpDown.Position);
    TSubPlot(PlotM.Subplot[i]).Bs2 := deg2rad(BS2UpDown.Position);
    TSubPlot(PlotM.Subplot[i]).Bs3 := deg2rad(BS3UpDown.Position);
  end;
  // Apply leaf angles to all species
  for i := 0 to PlotM.Species.Count - 1 do
  begin
    TSpecies(PlotM.Species[i]).Bl1 := deg2rad(BL1UpDown.Position);
    TSpecies(PlotM.Species[i]).Bl2 := deg2rad(BL2UpDown.Position);
    TSpecies(PlotM.Species[i]).Bl3 := deg2rad(BL3UpDown.Position);

    if i = 0 then
    begin
      DebugLn('Bl1: '+ FloatToStr(round(rad2deg(TSpecies(PlotM.Species[i]).Bl1))));
      DebugLn('Bl2: '+ FloatToStr(round(rad2deg(TSpecies(PlotM.Species[i]).Bl2))));
      DebugLn('Bl3: '+ FloatToStr(round(rad2deg(TSpecies(PlotM.Species[i]).Bl3))));
    end;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(PlotM);
end;

procedure TForm1.IndListBoxClick(Sender: TObject);
var
  t: integer;
begin
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).subplot.hash;
  SubplotListBox.ItemIndex := PlotM.HTSubPlot.Getindex(t);
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).species.hash;
  SpeciesListBox.ItemIndex := PlotM.HTSpecies.Getindex(t);
end;

procedure TForm1.SubplotListBoxClick(Sender: TObject);
var
  t: integer;
begin
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).subplot.hash;
  SubplotListBox.ItemIndex := PlotM.HTSubPlot.Getindex(t);
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).subplot.hash;
  SpeciesListBox.ItemIndex := PlotM.HTSpecies.Getindex(t);
end;

procedure TForm1.SpeciesListBoxClick(Sender: TObject);
var
  t: integer;
begin
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).subplot.hash;
  SubplotListBox.ItemIndex := PlotM.HTSubPlot.Getindex(t);
  t := TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).species.hash;
  SpeciesListBox.ItemIndex := PlotM.HTSpecies.Getindex(t);
end;

procedure TForm1.LightAbsOutCheckBoxClick(Sender: TObject);
begin
  if LightAbsOutCheckBox.Checked then
    PhotosynthOutCheckBox.State := cbChecked
  else
    PhotosynthOutCheckBox.State := cbGrayed;
end;

procedure TForm1.OvercastCheckBoxClick(Sender: TObject);
begin
  I_difUpDown.Enabled := OvercastCheckBox.Checked;
  I_difEdit.Enabled := OvercastCheckBox.Checked;
end;

procedure TForm1.f_RdUpDownClick(Sender: TObject);
begin
  f_RdEdit.Text := floattostr(f_RdUpDown.position / 100);
end;

procedure TForm1.f_RdEditChange(Sender: TObject);
var
  i: integer;
begin
  i := round(strtofloat(f_RdEdit.Text) * 100);
  if (i < 0) or (i > 100) then
    f_RdEdit.Text := floattostr(f_RdUpDown.position / 100)
  else
    f_RdUpDown.position := round(strtofloat(f_RdEdit.Text) * 100);
end;

procedure TForm1.AngleOptsCheckBoxClick(Sender: TObject);
var
  i: integer;
begin
  Panel1.Enabled := AngleOptsCheckBox.Checked;
  for i := 0 to Panel1.ControlCount - 1 do
    Panel1.Controls[i].Enabled := AngleOptsCheckBox.Checked;
end;

procedure TForm1.RunButtonClick(Sender: TObject);
var
  i: integer;
  runtime: cardinal;
begin
  runtime := GetTickCount64;
  ProgressBar1.Position := 0;
  try { Finally statement below makes sure cursor gets back to normal }
    RunButton.Enabled := False;
    Screen.Cursor := crHourglass;

    Form1.Tabsheet3.Enabled := True;
    Form1.Tabsheet4.Enabled := True;
    Calculate := TCalc.Create(PlotM, GDayUpDown.Position, GLayerUpDown.Position);

    DebugLn('-- Running calculations --');
    DebugLn('GP_day: ' + IntToStr(Calculate.GP_day));
    DebugLn('GP_layer: ' + IntToStr(Calculate.GP_layer));

    SetOptionsPlotM;

    ProgressBar1.Max := PlotM.Individual.Count;
    for i := 0 to PlotM.Individual.Count - 1 do
    begin
      Calculate.calc(TIndividual(PlotM.Individual[i]).hash, PlotM.doy);
      ProgressBar1.Position := i + 1;
    end;
  finally
    RunButton.Enabled := True;
    Screen.Cursor := crDefault;
    FreeAndNil(Calculate);
  end;

  runtime := GetTickCount64 - RunTime;
  RuntimeEdit.Text := IntToStr(round(runtime / 1000));
end;

procedure TForm1.DisplayButtonClick(Sender: TObject);
var
  i: integer;
begin
  try { Finally statement below makes sure cursor gets back to normal }
    Screen.Cursor := crHourglass;

    Form1.Tabsheet3.Enabled := True;
    Form1.Tabsheet4.Enabled := True;

    Calculate := TCalc.Create(PlotM, GDayUpDown.Position, GLayerUpDown.Position);
    SetOptionsPlotM;

    Calculate.calc(PlotM.HTIndividual.ELFHash(IndListBox.Items[IndListBox.ItemIndex]), PlotM.doy);

  finally
    Screen.Cursor := crDefault;
  end;

  ResultMemo.Text := 'Plant ' + TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(
    IndListBox.Items[IndListBox.ItemIndex])]).Name;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Day photosynthesis';
  for i := 0 to length(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(
      IndListBox.Items[IndListBox.ItemIndex])]).layer) - 1 do
  begin
    ResultMemo.Text := ResultMemo.Text + #13 + #10 + floattostr(
      TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).layer[i].P);
  end;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Total:' + #13 + #10 +
    floattostr(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).P_totd);

  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Plant ' + TIndividual(
    PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).Name;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Day photosynthesis-night resp.';
  for i := 0 to length(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(
      IndListBox.Items[IndListBox.ItemIndex])]).layer) - 1 do
  begin
    ResultMemo.Text := ResultMemo.Text + #13 + #10 + floattostr(
      TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).layer[i].P -
      TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).layer[i].R_dn);
  end;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Total:' + #13 + #10 +
    floattostr(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).P_totd -
    TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).R_dntot);

  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Plant ' + TIndividual(
    PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).Name;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Day PPFD absorption';
  for i := 0 to length(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(
      IndListBox.Items[IndListBox.ItemIndex])]).layer) - 1 do
  begin
    ResultMemo.Text := ResultMemo.Text + #13 + #10 + floattostr(
      TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).layer[i].I_abs);
  end;
  ResultMemo.Text := ResultMemo.Text + #13 + #10 + 'Total:' + #13 + #10 +
    floattostr(TIndividual(PlotM.Individual[PlotM.HTIndividual.GetStrIndex(IndListBox.Items[IndListBox.ItemIndex])]).I_abstot);

  FreeAndNil(Calculate);

  Form1.PageControl1.ActivePageIndex := 2;
end;

procedure TForm1.SaveButtonClick(Sender: TObject);
begin
  Output := TWriteExcel.Create;
  Output.PlotW := PlotM;
  // Set what to write to file
  Output.layers := LayersOutCheckBox.Checked;
  Output.light := LightAbsOutCheckBox.Checked;
  case PhotosynthOutCheckBox.state of
    cbUnchecked: Output.photosynth := False
    else // cbChecked or cbGrayed
      Output.photosynth := True;
  end;

  SaveDialog1.Filter := 'Excel files (*.xls)|*.xls;*.XLS';
  if SaveDialog1.Execute then
    Output.xlsname := SaveDialog1.FileName;

  if not Output.Write then
    MessageDlg('Error writing file: ' + Output.xlsname, mtInformation, [mbOK], 0);
  FreeAndNil(Output);
end;

procedure TForm1.ExitButtonClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.RunMTButtonClick(Sender: TObject);
var
  i, j: integer;
  runtime: cardinal;
  //madethread:boolean;

  procedure makethread(nr: integer);
  begin
    ThreadList.Add(TCalcThread.Create(True, TIndividual(PlotM.Individual[nr]).hash, PlotM.doy));
    TCalcThread(ThreadList.Items[ThreadList.Count - 1]).Calculate := TCalc.Create(PlotM, GDayUpDown.Position, GLayerUpDown.Position);
    TCalcThread(ThreadList.Items[ThreadList.Count - 1]).Start;
    //madethread:=true;
  end;

begin
  runtime := GetTickCount64;
  try { Finally statement below makes sure cursor gets back to normal }
    RunMTButton.Enabled := False;
    Screen.Cursor := crHourglass;

    SetOptionsPlotM;

    Form1.Tabsheet3.Enabled := True;
    Form1.Tabsheet4.Enabled := True;

    ProgressBar1.Max := PlotM.Individual.Count - 1;
    ThreadList := TObjectList.Create;
    ThreadList.OwnsObjects := True;
    //ThrSemaphore:=CreateSemaphore(nil,ThreadNoUpDown.Position,ThreadNoUpDown.Position,'threadcnt');
    ThrSemaphore := SemaphoreInit;
    if ThrSemaPhore = Pointer(-1) then
      exit;
    i := 0;
    repeat
      //madethread:=false;
      if ThreadList.Count = 0 then
      begin
        //if WaitForSingleObject(ThrSemaphore,10)=WAIT_OBJECT_0 then
        SemaphoreWait(ThrSemaphore);
        begin
          makethread(i); // first thread
          Inc(i);
        end;
      end
      else
      begin
        // Test if threads are finished
        //if WaitForSingleObject(ThrSemaphore,10)=WAIT_OBJECT_0 then
        SemaphoreWait(ThrSemaphore);
        // Thread is signaled
        // Check for the finished thread
        for j := 0 to ThreadList.Count - 1 do
          if TCalcThread(ThreadList.Items[j]).ReturnValue = 1 then
          begin
            ThreadList.Delete(j);
            makethread(i);
            Inc(i);
            Break;
          end
          else
          if ThreadList.Count < ThreadNoUpDown.Position then
          begin
            makethread(i);
            Inc(i);
            Break;
          end;
      end;
      ProgressBar1.Position := i - ThreadNoUpDown.Position;
    until i > PlotM.Individual.Count - 1;

    // Wait for threads to finalise
    while ThreadList.Count > 0 do
      for j := 0 to ThreadList.Count - 1 do
        if TCalcThread(ThreadList.Items[j]).ReturnValue = 1 then
        begin
          ProgressBar1.Position := ProgressBar1.Position + 1;
          ThreadList.Delete(j);
          Break;
        end;
    ProgressBar1.Position := 0;
  finally
    FreeAndNil(ThreadList);
    SemaphoreDestroy(ThrSemaphore);
    RunMTButton.Enabled := True;
    Screen.Cursor := crDefault;
  end;
  runtime := GetTickCount64 - RunTime;
  RuntimeEdit.Text := IntToStr(round(runtime / 1000));
end;

{ TCalcThread }

procedure TCalcThread.sync;
begin
  Application.MessageBox('fout', 'fout');
end;

procedure TCalcThread.Execute;
begin
  Calculate.Calc(ind, date);
  //if not ReleaseSemaphore(ThrSemaphore,  // handle to semaphore
  //                         1,             // increase count by one
  //                         nil) then
  SemaphorePost(ThrSemaphore);
  //Synchronize(sync); // Error message
  ReturnValue := 1;
end;

constructor TCalcThread.Create(CreateSuspended: boolean; i, d: integer);
begin
  ind := i;
  date := d;
  inherited Create(CreateSuspended);
end;

{ /TCalcThread }

end.
