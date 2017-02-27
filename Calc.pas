unit Calc;

{$MODE objfpc}{$H+}

// Model calculations

// Copyright (c), 2004-2006, Roelof Oomen

interface

uses Data_defs, Uhashtable, GaussInt;

type

  P_layer = class(TGaussInt) // Instantaneous layer photosynthesis integration class
  protected
    Pind, Pdate: integer;
    Ptime: double;
  public
    PlotP: TPlot;
    no_layer: integer;

    function fuGI(const xGI: double): double; override;
    // Gives photosynthesis speed for Pind, in no_layer, at Pdate and Ptime
    // at position xGI in the layer
    // xGI is expressed as F_cum at a certain position in the layer

    // Inherited function Integrate integrates fuGI over the F_cum interval
    // between bottom and top of layer no_layer, yielding instantaneous layer
    // photosynthesis speed
  end;

  P_day = class(P_layer) // Daily photosynthesis integration class
  private
    procedure wr_ind(x: integer);
    procedure wr_date(x: integer);
    procedure wr_time(x: double);

  public
    P_l: P_layer; // Used to calculate the integrals of the layers

    property Ind: integer read PInd write wr_ind;
    property date: integer read Pdate write wr_date;
    property time: double read Ptime write wr_time;

    constructor Create;
    function fuGI(const xGI: double): double; override;
    // Gives total layer photosynthesis speed for Ind and no_layer at Date
    // and at time xGI

    // Inherited function Integrate integrates fuGI over the time interval
    // between sunrise and sunset for layer no_layer, yielding daily photosynthesis

    destructor Destroy; override;
  end;

  I_layer = class(TGaussInt)
    // Instantaneous layer light interception integration class
  protected
    Iind, Idate: integer;
    Itime: double;
  public
    PlotI: TPlot;
    no_layer: integer;

    function fuGI(const xGI: double): double; override;
    // xGI is position in layer expressed as F_cum at that position
  end;

  I_day = class(I_layer) // Daily light interception integration class
  private
    procedure wr_ind(x: integer);
    procedure wr_date(x: integer);
    procedure wr_time(x: double);

  public
    I_l: I_layer; // Used to calculate the integrals of the layers

    property Ind: integer read IInd write wr_ind;
    property date: integer read Idate write wr_date;
    property time: double read Itime write wr_time;

    constructor Create;
    function fuGI(const xGI: double): double; override;
    // xGI is time
    destructor Destroy; override;
  end;
  // Warning: For layer integration procedures above make sure that the
  //   integration interval is never set outside layer borders (F_cum at layer
  //   bottom and top), otherwise integration result is undefined. This is
  //   because the layer fuGI() function uses these layer borders to calculate
  //   the N-content accompanying the specified position in the layer.

  // This calculates the photosynthesis and light absorption of a plant
  TCalc = class
  private
    // Number of points for Gaussian integration
    //   possible range 3-40, default 8 for day, 5 for layer
    FGP_day: integer;
    FGP_layer: integer;
    // Integrations
    P_d: P_day;
    I_d: I_day;
    // The plot
    PlotC: TPlot;
  public
    constructor Create(Plot: TPlot; _GP_day, _GP_layer: integer);
    procedure Calc(ind_hash, date: integer);

    property GP_day: integer read FGP_day;
    property GP_layer: integer read FGP_layer;
  end;

implementation

uses
  SysUtils;

{ P_layer }

function P_layer.fuGI(const xGI: double): double;
  // xGI is position in layer expressed as F_cum at that position
var
{    NT,  // Temp var. for N content at a certain depth xGI in the layer
    Pos,  }
  IncT: double;

begin
  with Tindividual(PlotP.Individual[PlotP.HTIndividual.GetIndex(Pind)]) do
  begin

{        // Pos is position in layer as a fraction
        if high(Subplot.F_cum)>no_layer then
            // Not the top layer
            if Subplot.F_part[no_layer]=0 then // Prevent div. by zero
                Pos:=0
            else
                Pos:= (Subplot.F_cum[no_layer] - xGI) /
                      (Subplot.F_cum[no_layer] - Subplot.F_cum[no_layer+1])
        else
            // Top layer
            Pos:= (Subplot.F_cum[no_layer] - xGI) / Subplot.F_cum[no_layer];

        if high(layer)>no_layer then
            // Not the top layer
            NT:= (1-Pos) * layer[no_layer].N_bot +
                    Pos  * layer[no_layer+1].N_bot
        else
            // Top layer
            NT:= (1-Pos) * layer[no_layer].N_bot +
                    Pos  * (layer[no_layer].N_av-layer[no_layer].N_bot+layer[no_layer].N_av);}

    IncT := PlotP.inclination(Pdate, Ptime);
    Result := P_tot(IncT, layer[no_layer].N_av, xGI);
  end;
end;

constructor TCalc.Create(Plot: TPlot; _GP_day, _GP_layer: integer);
begin
  //inherited;
  PlotC := Plot;
  FGP_day := _GP_day;
  FGP_layer := _GP_layer;
end;

{ P_day }

constructor P_day.Create;
begin
  inherited;
  P_l := P_layer.Create;
end;

destructor P_day.Destroy;
begin
  FreeAndNil(P_l);
  inherited;
end;

function P_day.fuGI(const xGI: double): double;
  // Calculates a photosynthesis speed for time of the day xGI
  // This function performs also error checks for two biologically impossible situations:
  //     LE_Fvegzero : If F_veg=0 while layer.F>0

begin
  with Tindividual(PlotP.Individual[PlotP.HTIndividual.GetIndex(ind)]) do
  begin
    time := xGI;
    P_l.no_layer := no_layer;

    // Check for individual with more layers than subplot, or for zero F
    //TODO: individual with more layers than subplot needs specific error
    if ((no_layer+1)>Length(subplot.F_part)) or ((subplot.F_part[no_layer] * subplot.F_veg) = 0) then
    begin
      if layer[no_layer].F > 0 then
        layer[no_layer].error := layer[no_layer].error or LE_Fvegzero;
      Result := 0;
    end
    else
    begin
      // Layer photosynth per sec * 3600 -> per hour
      if high(Subplot.F_cum) > no_layer then
        Result := 3600 * layer[no_layer].F / (subplot.F_part[no_layer] * subplot.F_veg) *
          P_l.integrate(subplot.F_cum[no_layer + 1], subplot.F_cum[no_layer])
      else { Top layer }
        Result := 3600 * layer[no_layer].F / (subplot.F_part[no_layer] * subplot.F_veg) *
          P_l.integrate(0, subplot.F_cum[no_layer]);
    end;
  end;
end;

procedure P_day.wr_date(x: integer);
begin
  Pdate := x;
  P_l.Pdate := x;
end;

procedure P_day.wr_ind(x: integer);
begin
  Pind := x;
  P_l.Pind := x;
end;

procedure P_day.wr_time(x: double);
begin
  Ptime := x;
  P_l.Ptime := x;
end;

{ I_layer }

function I_layer.fuGI(const xGI: double): double;
  // xGI is position in layer expressed as F_cum at that position
var
  {Pos, NT,} IncT: double; // Temp var. for N content and F_cum at
  // a certain depth xGI in the layer
begin
  with Tindividual(PlotI.Individual[PlotI.HTIndividual.GetIndex(Iind)]) do
  begin

{        // Pos is position in layer as a fraction
        if high(Subplot.F_cum)>no_layer then
            // Not the top layer
            if Subplot.F_part[no_layer]=0 then // Prevent div. by zero
                Pos:=0
            else
                Pos:= (Subplot.F_cum[no_layer] - xGI) /
                      (Subplot.F_cum[no_layer] - Subplot.F_cum[no_layer+1])
        else
            // Top layer
            Pos:= (Subplot.F_cum[no_layer] - xGI) / Subplot.F_cum[no_layer];

        if high(layer)>no_layer then
            // Not the top layer
            NT:= (1-Pos) * layer[no_layer].N_bot +
                    Pos  * layer[no_layer+1].N_bot
        else
            // Top layer
            NT:= (1-Pos) *  layer[no_layer].N_bot +
                    Pos  * (layer[no_layer].N_av-layer[no_layer].N_bot+layer[no_layer].N_av);}

    IncT := PlotI.inclination(Idate, Itime);
    Result := I_dif(IncT, layer[no_layer].N_av, xGI) + I_scat(
      IncT, layer[no_layer].N_av, xGI) + I_dir(IncT, layer[no_layer].N_av) * f_sl(IncT, xGI);
  end;
end;

{ I_day }

constructor I_day.Create;
begin
  inherited;
  I_l := I_layer.Create;
end;

destructor I_day.Destroy;
begin
  FreeAndNil(I_l);
  inherited;
end;

function I_day.fuGI(const xGI: double): double;
begin
  with Tindividual(PlotI.Individual[PlotI.HTIndividual.GetIndex(ind)]) do
  begin
    time := xGI;
    I_l.no_layer := no_layer;

    if ((no_layer+1)<=Length(subplot.F_part)) and ((subplot.F_part[no_layer] * subplot.F_veg) <> 0) then
    begin
      // Layer PPFD absorption per sec * 3600 -> per hour
      if high(Subplot.F_cum) > no_layer then
        Result := 3600 * I_l.integrate(subplot.F_cum[no_layer + 1],
          subplot.F_cum[no_layer]) * (layer[no_layer].F / (subplot.F_part[no_layer] * subplot.F_veg))
      else
        Result := 3600 * I_l.integrate(0,
          subplot.F_cum[no_layer]) * (layer[no_layer].F / (subplot.F_part[no_layer] * subplot.F_veg));
    end
    else
      // Actual error check is done in P_day.fuGI()
      Result := 0;
  end;
end;

procedure I_day.wr_date(x: integer);
begin
  Idate := x;
  I_l.Idate := x;
end;

procedure I_day.wr_ind(x: integer);
begin
  Iind := x;
  I_l.Iind := x;
end;

procedure I_day.wr_time(x: double);
begin
  Itime := x;
  I_l.Itime := x;
end;

{ TCalc }

procedure TCalc.calc(ind_hash, date: integer);
var
  i: integer;
  SumT1, SumT2: double;

begin

  if ((Tindividual(PlotC.Individual[PlotC.HTIndividual.GetIndex(ind_hash)]).error and
    IE_NoSpecies) = IE_NoSpecies) or
    ((Tindividual(PlotC.Individual[PlotC.HTIndividual.GetIndex(ind_hash)]).error and
    IE_NoSubplot) = IE_NoSubplot) then
    exit;

  { Initalise Photosynthesis integration object }
  P_d := P_day.Create;
  P_d.PlotP := PlotC;
  P_d.P_l.PlotP := PlotC;
  P_d.ind := ind_hash;
  P_d.date := date;
  P_d.GP := GP_day; { Integration points }
  P_d.P_l.GP := GP_layer;

  { Initalise Light absorption integration object }
  I_d := I_day.Create;
  I_d.PlotI := PlotC;
  I_d.I_l.PlotI := PlotC;
  I_d.ind := ind_hash;
  I_d.date := date;
  I_d.GP := GP_day; { Integration points }
  I_d.I_l.GP := GP_layer;

  SumT1 := 0;
  // First initialise layer's N_bot values by interpolation
  //   and calculate total leaf area of plant
  with Tindividual(PlotC.Individual[PlotC.HTIndividual.GetIndex(ind_hash)]) do
  begin
    for i := high(Layer) downto 0 do
    begin
            {if i=0 then
                if high(layer)=0 then // plant with only 1 layer
                    Layer[i].N_bot:=Layer[i].N_av
                else
                    Layer[i].N_bot:=Layer[i].N_av-(Layer[i+1].N_bot-Layer[i].N_av)
            else
                Layer[i].N_bot:=(Layer[i-1].N_av+Layer[i].N_av)/2;}
      SumT1 := SumT1 + Layer[i].F;
    end;
    F_tot := SumT1;
  end;

  SumT1 := 0;
  SumT2 := 0;
  // Integrate P for each layer for the whole day
  with Tindividual(PlotC.Individual[PlotC.HTIndividual.GetIndex(ind_hash)]) do
  begin
    for i := 0 to high(Layer) do
    begin
      P_d.No_layer := i;

      layer[i].P := P_d.integrate(12 - (0.5 * PlotC.daylength(date)),
        12 + (0.5 * PlotC.daylength(date))) / 1000000;
      // division by 1000000 to get mol/day
      SumT1 := SumT1 + layer[i].P;

      // Note: No checking for possibly faulty data here, this
      //       is already taken care of in the P calculation
      if ((i+1)>Length(subplot.F_part)) or ((subplot.F_part[i] * subplot.F_veg) = 0) then
        layer[i].R_dn := 0
      else
        layer[i].R_dn :=
          (24 - PlotC.daylength(date)) * 3600 * (layer[i].F) *
          Species.R_d(Layer[i].N_av) * Species.f_Rd / 1000000;
      SumT2 := SumT2 + layer[i].R_dn;

      Error := Error or layer[i].error;
    end;
    P_totd := SumT1;
    R_dntot := SumT2;
  end;

  SumT1 := 0;
  // Integrate I absorbed for each layer for the whole day
  with Tindividual(PlotC.Individual[PlotC.HTIndividual.GetIndex(ind_hash)]) do
  begin
    for i := 0 to high(Layer) do
    begin
      I_d.No_layer := i;
      layer[i].I_abs := I_d.integrate(12 - (0.5 * PlotC.daylength(date)), 12 +
        (0.5 * PlotC.daylength(date))) / 1000000;
      SumT1 := SumT1 + layer[i].I_abs;
    end;
    I_abstot := SumT1;
  end;

  FreeAndNil(I_d);
  FreeAndNil(P_d);
end;

end.
