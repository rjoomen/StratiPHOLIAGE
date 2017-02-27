unit Data_RW;

{$MODE objfpc}{$H+}

// Copyright (c), 2004-2017, Roelof Oomen

// Read/Write of Data

// Reading is done with fpspreadsheet (replaces Windows OLE automation
//   implementation of previous versions)
// Writing is done using unit UExcel.
// Note: writing could be replaced by fpspreadsheet (would support more file
//   formats, and would allow for removing UExcel).

interface

uses
  fpspreadsheet, UExcel,
  Data_defs;

type
  TPlotWB = class
  private
    // Same as StrToFloat, but also converts empty strings to zero
    function StringToFloat(const S: string): extended;

    function readplot(Sheet: TsWorksheet): boolean;
    function readspecies(Sheet: TsWorksheet): boolean;
    function readsubplots(Sheet: TsWorksheet): boolean;
    function readindividuals(Sheet: TsWorksheet): boolean;

  public
    PlotWB: TPlot;
    filename: string;
    function WBRead: integer;
  end;

  TWriteExcel = class(WriteXLS)
    PlotW: TPlot;
    layers: boolean;
    light: boolean;
    photosynth: boolean;

    xlsname: string;

    function Write: boolean;
  end;


implementation

uses
  SysUtils, User_int, fpsutils,
  // fpspreadsheet supported file formats
  xlsbiff2, xlsbiff5, xlsbiff8, xlsxooxml, fpsopendocument,
  Uhashtable;

function TPlotWB.StringToFloat(const S: string): extended;
  // Empty string is converted to 0
begin
  if S = '' then
    Result := 0
  else
    Result := StrToFloat(S);
end;

function TPlotWB.readplot(Sheet: TsWorksheet): boolean;
begin
  if (Sheet.GetLastRowIndex() < 2) or (Sheet.GetLastColIndex() < 5) then
  begin
    Result := False;
    exit;
  end;

  PlotWB.Name := Sheet.ReadAsUTF8Text(2, 0);
  PlotWB.latitude := Sheet.ReadAsNumber(2, 1) * (pi / 180); // Convert to radians
  //PlotWB.Thickness := Sheet.ReadAsNumber(2,2);
  PlotWB.rho := Sheet.ReadAsNumber(2, 3);
  PlotWB.alpha_veg := Sheet.ReadAsNumber(2, 4);
  PlotWB.doy := round(Sheet.ReadAsNumber(2, 5));

  Form1.DataMemo.Text := 'Plot: ' + PlotWB.Name + ' Latitude: ' + floattostr(PlotWB.Latitude);
  Form1.PlotNameEdit.Text := PlotWB.Name;
  Form1.PlotNameEdit.Repaint;

  Result := True;
end;

function TPlotWB.readspecies(Sheet: TsWorksheet): boolean;
var
  i, indexT: integer;
  SpeciesT: TSpecies;
begin
  if (Sheet.GetLastColIndex() < 13) then
  begin
    Result := False;
    exit;
  end;

  Form1.DataMemo.Text := Form1.DataMemo.Text + #13 + #10 + 'name (hash) a_p b_p c_p p_lin a_r b_r ' +
    'phi_Inc Theta a_chl b_chl c_chl f1 f2 f3';

  SpeciesT := TSpecies.Create;

  for i := 2 to Sheet.GetLastRowIndex() do
    with SpeciesT do
      with Sheet.cells do
      begin

        SpeciesT.Name := Sheet.ReadAsUTF8Text(i, 0);
        if SpeciesT.Name = '' then
          break; // Stop at first empty line
        hash := PlotWB.HTSpecies.ELFHash(SpeciesT.Name);


        a_p := Sheet.ReadAsNumber(i, 1);
        b_p := Sheet.ReadAsNumber(i, 2);
        c_p := Sheet.ReadAsNumber(i, 3);
        if c_p = 0 then
          P_Lin := True
        else
          P_Lin := False;

        a_r := Sheet.ReadAsNumber(i, 4);
        b_r := Sheet.ReadAsNumber(i, 5);

        Phi := Sheet.ReadAsNumber(i, 6);
        Theta := Sheet.ReadAsNumber(i, 7);

        a_Chl := Sheet.ReadAsNumber(i, 8);
        b_Chl := Sheet.ReadAsNumber(i, 9);
        c_Chl := Sheet.ReadAsNumber(i, 10);

        f1 := Sheet.ReadAsNumber(i, 11);
        f2 := Sheet.ReadAsNumber(i, 12);
        f3 := Sheet.ReadAsNumber(i, 13);

        Form1.DataMemo.Text :=
          Form1.DataMemo.Text + #13 + #10 + SpeciesT.Name + ' (' + IntToStr(hash) + ') ' +
          floattostr(a_p) + ' ' + floattostr(b_p) + ' ' + floattostr(c_p) + ' ' + booltostr(p_lin) +
          ' ' + floattostr(a_r) + ' ' + floattostr(b_r) + ' ' + floattostr(phi) + ' ' +
          floattostr(Theta) + ' ' + floattostr(a_chl) + ' ' + floattostr(b_chl) + ' ' +
          floattostr(c_chl) + ' ' + floattostr(f1) + ' ' + floattostr(f2) + ' ' + floattostr(f3);

        indexT := PlotWB.species.Add(SpeciesT);
        if not PlotWB.HTSpecies.InsertHash(hash, IndexT) then
          TSpecies(PlotWB.Species[indexT]).Error := IE_HashCollision;
        Form1.SpeciesListBox.AddItem(SpeciesT.Name, TSpecies(PlotWB.Species[indexT]));
        SpeciesT := TSpecies.Create;

        Form1.SpeciesCountEdit.Text := IntToStr(PlotWB.Species.Count);
        Form1.SpeciesCountEdit.Repaint;
      end;

  Form1.DataMemo.Repaint;
  FreeAndNil(SpeciesT);
  Result := True;
end;

function TPlotWB.readsubplots(Sheet: TsWorksheet): boolean;
var
  i, j, indexT: integer;
  l: double;
  SubplotT: TSubplot;
begin
  if (Sheet.GetLastColIndex() < 8) then // Should at least have 1 layer
  begin
    Result := False;
    exit;
  end;

  Form1.DataMemo.Text := Form1.DataMemo.Text + #13 + #10 + 'name (hash) F_veg f1 f2 f3 K_Veg no_layers';

  SubplotT := TSubplot.Create;

  for i := 2 to Sheet.GetLastRowIndex() do
    with SubplotT do
      with Sheet.cells do
      begin
        SubplotT.Name := Sheet.ReadAsUTF8Text(i, 0);
        if SubplotT.Name = '' then
          break; // Stop at first empty line
        hash := PlotWB.HTSubplot.ElfHash(SubplotT.Name);

        area := Sheet.ReadAsNumber(i, 1);
        F_Veg := Sheet.ReadAsNumber(i, 2);
        f1 := Sheet.ReadAsNumber(i, 3);
        f2 := Sheet.ReadAsNumber(i, 4);
        f3 := Sheet.ReadAsNumber(i, 5);
        // If only one f-value is given and it's larger than one it is the
        //   average leaf angle
        if (f2 = 0) and (f3 = 0) and (f1 > 1) then
          SubplotT.Av_Angle := f1;
        K_Veg := Sheet.ReadAsNumber(i, 6);
        no_Layers := round(Sheet.ReadAsNumber(i, 7));
        if no_layers <= 0 then
        begin
          Result := False;
          exit;
        end;

        setlength(F_Part, no_layers);
        setlength(F_cum, no_layers);
        setlength(I_rel, no_layers);

        /////////// NOTE: Versions before 1.2.1 used the following erronous code for calculating the F_cum[]
{            l:=0;
            for j:=0 to no_layers-1 do // Read layers
            begin
                F_Part[j]:=Sheet.ReadAsNumber(i,j+9);
                if j<>0 then
                    l:=l+F_Part[j-1];
                F_cum[j]:= F_veg - F_veg*l; // Cumulative F at bottom of layer (seen from below)
                I_rel[j]:= exp(-K_veg*F_cum[j]);
            end;}

        for j := 0 to no_layers - 1 do // Read layers
        begin
          F_Part[j] := Sheet.ReadAsNumber(i, j + 8);
        end;
        l := 0;
        for j := no_layers - 1 downto 0 do // Read layers
        begin
          l := l + F_Part[j];
          F_cum[j] := F_veg * l; // Cumulative F at bottom of layer (seen from below)
          I_rel[j] := exp(-K_veg * F_cum[j]);
        end;

        Form1.DataMemo.Text :=
          Form1.DataMemo.Text + #13 + #10 + SubplotT.Name + ' (' + IntToStr(hash) + ') ' +
          floattostr(F_veg) + ' ' + floattostr(f1) + ' ' + floattostr(f2) + ' ' + floattostr(f3) +
          ' ' + floattostr(K_Veg) + ' ' + IntToStr(no_layers);

        indexT := PlotWB.Subplot.Add(SubplotT);
        if not PlotWB.HTSubplot.InsertHash(hash, indexT) then
          TSubPlot(TSubPlot(PlotWB.Subplot[indexT])).Error := IE_HashCollision;
        Form1.SubplotListBox.AddItem(SubplotT.Name, TSubPlot(PlotWB.Subplot[indexT]));
        SubplotT := TSubplot.Create;

        Form1.SubplotCountEdit.Text := IntToStr(PlotWB.SubPlot.Count);
        Form1.SubplotCountEdit.Repaint;
      end;

  Form1.DataMemo.Repaint;
  FreeAndNil(SubPlotT);
  Result := True;
end;

function TPlotWB.readindividuals(Sheet: TsWorksheet): boolean;
var
  i, indexT, no_l: integer;
  NameT1, NameT2: string;
  IndNameT, IndNamePrev: string;
  IndividualT: TIndividual;
begin
  if (Sheet.GetLastColIndex() < 8) then
  begin
    Result := False;
    exit;
  end;

  Form1.DataMemo.Text := Form1.DataMemo.Text + #13 + #10 + 'subplot species name (hash) no_l';

  IndNamePrev := Sheet.ReadAsUTF8Text(2, 2);

  for i := 2 to Sheet.GetLastRowIndex() do
    with IndividualT do
    begin

      IndNameT := Sheet.ReadAsUTF8Text(i, 2);
      if IndNameT = '' then
        break; // Stop at first empty line

      IndividualT := TIndividual.Create;
      IndividualT.Name := IndNameT;
      hash := PlotWB.HTIndividual.ElfHash(IndividualT.Name);
      individualT.plot := PlotWB;

      // Check if accompanying Subplot and Species data are present
      if PlotWB.HTSpecies.getStrindex(Sheet.ReadAsUTF8Text(i, 1)) = -1 then
      begin { No Species data }
        individualT.Error := individualT.Error or IE_NoSpecies;
        if individualT.species = nil then
          individualT.species := TSpecies.Create;
      end
      else
        individualT.species := TSpecies(PlotWB.species[PlotWB.HTspecies.getstrindex(Sheet.ReadAsUTF8Text(i, 1))]);

      if PlotWB.HTSubplot.getStrindex(Sheet.ReadAsUTF8Text(i, 0)) = -1 then
      begin { No Subplot data }
        individualT.Error := individualT.Error or IE_NoSubplot;
        if individualT.subplot = nil then
          individualT.subplot := TSubPlot.Create;
      end
      else
        individualT.subplot := TSubPlot(PlotWB.SubPlot[PlotWB.HTSubplot.getstrindex(Sheet.ReadAsUTF8Text(i, 0))]);

      no_l := round(Sheet.ReadAsNumber(i, 3));
      if no_l > length(layer) then
      begin
        setlength(layer, no_l);
      end;
      //layer[no_l-1].Thickness:=stringtofloat(Sheet.ReadAsNumber(i,4));
      //layer[no_l-1].LM:=stringtofloat(Sheet.ReadAsNumber(i,5));
      //layer[no_l-1].SM:=stringtofloat(Sheet.ReadAsNumber(i,6));
      layer[no_l - 1].F := Sheet.ReadAsNumber(i, 7);
      layer[no_l - 1].N_Av := Sheet.ReadAsNumber(i, 8);

      if individualT.Error and IE_NoSpecies = IE_NoSpecies then
        NameT1 := PlotWB.ErrStr(IE_NoSpecies)
      else
        NameT1 := species.Name;
      if individualT.Error and IE_NoSubplot = IE_NoSubplot then
        NameT2 := PlotWB.ErrStr(IE_NoSubplot)
      else
        NameT2 := subplot.Name;
      Form1.DataMemo.Text :=
        Form1.DataMemo.Text + #13 + #10 + nameT2 + ' ' + NameT1 + ' ' + IndividualT.Name + ' (' +
        IntToStr(hash) + ') ' + IntToStr(no_l);

      if PlotWB.HTIndividual.GetIndex(hash) = -1 then
      begin // Individual does not yet exist
        indexT := PlotWB.Individual.Add(IndividualT);
        // Temporary switch off collision detection, as we know already that hash does not exist yet.
        PlotWB.HTIndividual.collisiondetection := False;
        PlotWB.HTIndividual.InsertHash(hash, IndexT);
        PlotWB.HTIndividual.collisiondetection := True;
        Form1.IndListBox.AddItem(IndividualT.Name, TIndividual(PlotWB.Individual[IndexT]));
      end
      else // Individual exists, just add this layer
      begin
        if (IndividualT.Name <> IndNamePrev) then
          TIndividual(PlotWB.Individual[PlotWB.HTIndividual.GetIndex(hash)]).Error := IE_HashCollision;
        // Not the same individual as previous layer, but hash does exist already:
        //   either a hash table collision or layers of different plants are mixed.
        //   The latter is not a problem, but in that collision detection is not possible.

        if no_l > length(TIndividual(PlotWB.Individual[PlotWB.HTIndividual.GetIndex(hash)]).layer) then
          setlength(TIndividual(PlotWB.Individual[PlotWB.HTIndividual.GetIndex(hash)]).layer, no_l);
        TIndividual(PlotWB.Individual[PlotWB.HTIndividual.GetIndex(hash)]).layer[no_l - 1] := layer[no_l - 1];
        FreeAndNil(IndividualT);
      end;
      IndNamePrev := IndNameT;

      Form1.IndCountEdit.Text := IntToStr(PlotWB.Individual.Count);
      Form1.IndCountEdit.Repaint;
    end;

  Form1.DataMemo.Repaint;
  Result := True;
end;

function TPlotWB.WBRead: integer;
var
  WorkBook: TsWorkbook; // Spreadsheet workbook
begin

  // Create the spreadsheet
  Workbook := TsWorkbook.Create;
  try
    Workbook.ReadFromFile(filename);

    if WorkBook.GetWorksheetCount < 4 then
    begin
      Result := 1;
      exit;
    end;

    Form1.Edit2.Enabled := True;
    Form1.Edit2.Text := 'Plot';
    Form1.Edit2.Repaint;

    if not ReadPlot(WorkBook.GetWorksheetByIndex(0)) then
    begin
      Result := 2;
      exit;
    end;

    Form1.Edit2.Text := 'Species';
    Form1.Edit2.Repaint;

    if not ReadSpecies(WorkBook.GetWorksheetByIndex(1)) then
    begin
      Result := 3;
      exit;
    end;

    Form1.Edit2.Text := 'SubPlots';
    Form1.Edit2.Repaint;

    if not ReadSubPlots(WorkBook.GetWorksheetByIndex(2)) then
    begin
      Result := 4;
      exit;
    end;

    Form1.Edit2.Text := 'Individuals';
    Form1.Edit2.Repaint;

    if not ReadIndividuals(WorkBook.GetWorksheetByIndex(3)) then
    begin
      Result := 5;
      exit;
    end;

    Form1.Edit2.Text := 'Finished';
    Form1.Edit2.Repaint;
    Form1.Edit2.Enabled := False;
  finally
    FreeAndNil(WorkBook);
  end;

  Result := 0;
end;

{ TWriteExcel }

function TWriteExcel.Write: boolean;
var
  name_int, row, col, i, j: integer;
begin
  XlsOpen(xlsname);

  // Output Plot info
  XlsWriteCellLabel(0, 0, 'Plot name');
  XlsWriteCellLabel(1, 0, 'Latitude');
  XlsWriteCellLabel(2, 0, 'Date');
  XlsWriteCellLabel(0, 1, PlotW.Name);
  XlsWriteCellNumber(1, 1, PlotW.latitude / (pi / 180));
  XlsWriteCellNumber(2, 1, PlotW.doy);

  // Header row
  col := 0;
  XlsWriteCellLabel(col, 3, 'Subplot');
  Inc(col);
  XlsWriteCellLabel(col, 3, 'Name');
  Inc(col);
  XlsWriteCellLabel(col, 3, 'Number');
  Inc(col);
  if light then
  begin
    XlsWriteCellLabel(col, 3, 'PPFD absorption');
    Inc(col);
  end;
  if Photosynth then
  begin
    XlsWriteCellLabel(col, 3, 'Photosynthesis');
    Inc(col);
  end;
  XlsWriteCellLabel(col, 3, 'Remarks');

  row := 4;
  for i := 0 to PlotW.Individual.Count - 1 do
    with TIndividual(PlotW.Individual[i]) do
    begin
      col := 0;
      XlsWriteCellLabel(col, row, subplot.Name);
      Inc(col);

      XlsWriteCellLabel(col, row, species.Name);
      Inc(col);

      try
        name_int := StrToInt(Name);
        XlsWriteCellNumber(col, row, name_int); // save as integer
      except
        XlsWriteCellLabel(col, row, Name); // save as string
      end;

      Inc(col);

      if light then
      begin
        XlsWriteCellNumber(col, row, I_abstot);
        Inc(col);
      end;
      if Photosynth then
      begin
        XlsWriteCellNumber(col, row, P_totd - R_dntot);
        Inc(col);
      end;
      XlsWriteCellLabel(col, row, PlotW.ErrStr(Error or Subplot.Error or Species.Error));
      Inc(row);
    end;

  Inc(row);
  if layers then
  begin
    // New header row
    col := 0;
    XlsWriteCellLabel(col, row, 'Subplot');
    Inc(col);
    XlsWriteCellLabel(col, row, 'Name');
    Inc(col);
    XlsWriteCellLabel(col, row, 'Number');
    Inc(col);
    XlsWriteCellLabel(col, row, 'Layer');
    Inc(col);
    if light then
    begin
      XlsWriteCellLabel(col, row, 'PPFD absorption');
      Inc(col);
    end;
    if Photosynth then
    begin
      XlsWriteCellLabel(col, row, 'Photosynthesis');
      Inc(col);
    end;
    XlsWriteCellLabel(col, row, 'Remarks');
    Inc(Row);

    for i := 0 to PlotW.Individual.Count - 1 do
      with TIndividual(PlotW.Individual[i]) do
        for j := 0 to high(layer) do
        begin
          col := 0;
          XlsWriteCellLabel(col, row, subplot.Name);
          Inc(col);
          XlsWriteCellLabel(col, row, species.Name);
          Inc(col);

          try
            name_int := StrToInt(Name);
            XlsWriteCellNumber(col, row, name_int); // save as integer
          except
            XlsWriteCellLabel(col, row, Name); // save as string
          end;
          Inc(col);

          XlsWriteCellRk(col, row, j + 1);
          Inc(col);
          if light then
          begin
            XlsWriteCellNumber(col, row, layer[j].I_abs);
            Inc(col);
          end;
          if Photosynth then
          begin
            XlsWriteCellNumber(col, row, layer[j].P - layer[j].R_dn);
            Inc(col);
          end;
          XlsWriteCellLabel(col, row, PlotW.ErrStr(layer[j].Error or species.Error or subplot.Error));
          Inc(row);
        end;
  end;

  XlsClose;
  Result := True;
end;

end.
