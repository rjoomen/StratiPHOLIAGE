unit Data_defs;

{$MODE objfpc}{$H+}

// Data structure definitions
// and main model calculation methods

// Copyright (c), 2004-2006, Roelof Oomen

interface

uses
  Contnrs,
  Uhashtable;

const
  // Fractions of total diffuse light in the three sky zones
  Frac1 = 0.2;
  Frac2 = 0.3;
  Frac3 = 0.5;
  // Defaults for leaf angles
  r15 = 0.26179938779914943653855361527329; // 15 degrees in radians
  r45 = 0.78539816339744830961566084581988; // 45 degrees in radians
  r75 = 1.3089969389957471826927680763665;  // 75 degrees in radians
  // Default dark respiration
  f_Rd_def = 0.5;
  // Default overcast radiation
  I_overcast_def = 500;
  // Constants for atmospheric light attenuation
  tau = 0.6; // Atmosperic transmittance
  SC = 3190; // Sun constant: Total solar radiation above atmosphere in umol/m2/s

  // Errors in calculation
  // Layer errors
  LE_Fvegzero = 1; // If F_veg=0 while layer.F>0
  // Subplot area is not used anymore: plant LAI cannot be calculated
  //    LE_Fvegsmall = 2; // If F_veg<layer.F
  // Input errors
  IE_NoSpecies = 4; // No species data available
  IE_NoSubplot = 8; // No subplot data available
  IE_HashCollision = 16; // Hash table collision

type
  TPlot_p = class // Primitive Plot
    // (not containing subplots, species or individuals)
  public
    latitude: double;  // latitude _in radians!_
    Name: string;
    //thickness   : Double;  // General layer thickness, not used in calculations
    rho: double;  // Canopy reflection coefficient
    alpha_veg: double;  // Average leaf absorbance of plot
    doy: integer; // Date (in days from New Year)
    alpha_const: boolean; // If true, Individual.Alpha() returns Alpha_veg
    k_veg_data: boolean; // If true, Individual.I_dif is calculated
    //   using the subplot's k_veg specified in
    //   the input file (except when k_veg=0)
    Overcast: boolean; // Defines if incoming radiation is fixed as in an
    //   overcast day or is calculated during the day
    I_overcast: integer; // Incoming radiation above canopy during overcast day

    constructor Create;
  end;

  TSubPlot = class
  private
    procedure InitLeafAngles(angle: double);
    // Used to initialise f1..f3 out of an average angle.
    // f2 is fixed as 0.2
    function AverageAngle: double; // In degrees!
    // Averages f1..f3
    function O_av(Bl, Bs: double): double;
    // Average projection of a leaf with angle Bl to radiation with angle Bs
    // Uses leaf angle dist. of subplot
  public
    Name: string;
    hash: int64;

    area: double;  // Ground area in square meters
    F_veg: double;  // LAI of whole subplot
    f1, f2, f3: double;  // LA fractions in leaf angle classes
    Bl1, Bl2, Bl3: double;  // Average angle of leaves in each class
    Bs1, Bs2, Bs3: double;  // Average angle of radiation in each class
    K_veg: double;  // Exctinction of whole subplot
    no_layers: integer; // Number of layers
    F_part: array of double; // Array of 0..no_layers-1
    // each value is partition of total leaf
    // in that layer, hence sum must be 1
    F_cum: array of double; // Calculated from F_part, being
    // cumulative leaf area at bottom of layer,
    // hence F_cum[0] should equal F_veg
    I_rel: array of double; // Also calculated from F_part, being the
    // relative diffuse light partitioning in
    // the vegetation (calculated using K_veg)

    Error: word;

    property Av_Angle: double read AverageAngle write InitLeafAngles;
    // In degrees!
    function k_dif(F_cum_: double): double;
    function k_bl(Bs: double): double;

    constructor Create;
    // Initialises Bs's and Bl's to 15, 45 and 75 deg.
  end;

  TLayer = record // Plant layer characteristics
    //Thickness : Double; // Layer thickness, not used in calculations
    //LM        : Double; // Leaf mass, not used in calculations
    //SM        : Double; // Stem mass, not used in calculations
    F: double; // Leaf area
    N_av: double; // Average N content
    //N_bot     : Double; // N content at bottom of layer (interpolated)

    P: double; // Net daily (light period) photosynthesis
    // (integrated over depth in layer and over daylength)
    R_dn: double; // Total night respiration
    // Note: net 24h day photosysnthesis is: P minus R_dn
    I_abs: double; // Net daily PPFD absorption

    Error: word;
  end;

  TSpecies = class
  private
    function Chl(N: double): double; // Chlorofyl content
    function P_max(N: double): double; // Max photosynthesis
  public
    Name: string; // Species name
    hash: int64; // Species hash

    P_lin: boolean; // Indicates if Pmax formula is linear or not
    a_p, b_p, c_p: double;
    a_r, b_r: double;
    a_Chl, b_Chl, c_Chl: double;

    // Photosynthesis characteristics
    Phi: double; // Quantum yield (initial slope)
    Theta: double; // Curvature
    f_Rd: double;
    // Fraction of measured R_d in effect during the night

    f1, f2, f3: double; // LA fractions in leaf angle classes
    Bl1, Bl2, Bl3: double; // Average angle of leaves in each class
    //   initialised by constructor to 15, 45 and 75 deg.

    Error: word;

    function R_d(N: double): double; // Dark respiration
    function P_l(I, N: double): double; // Net leaf photosysnthesis

    constructor Create;
    // Initialises Bl's to 15, 45 and 75 deg.
  end;

  TIndividual = class
  private
    // Average projection of a leaf with angle Bl to radiation with angle Bs
    // Uses leaf angle dist. of species
    function O_av(Bl, Bs: double): double;
    function k_dif(F_cum: double): double;
    function k_bl(Bs: double): double;
    // Air mass for radiation at an angle Bs to pass through
    function M_air(Bs: double): double;
    // Absorption coefficient
    function Alpha(N: double): double;
  public
    // Plant name (usually a number)
    Name: string;
    hash: int64;

    plot: TPlot_p;
    species: TSpecies;
    subplot: TSubplot;
    layer: array of TLayer;
    // Total Leaf Area of whole plant (sum of all layer[x].F)
    F_tot: double;
    // Total daily photosynthesis of whole plant (sum of all layer[x].P)
    P_totd: double;
    // Total nightly respiration of whole plant (sum of all layer[x].R_dn)
    R_dntot: double;
    // Total daily PPFD absorption of whole plant (sum of all layer[x].I_abs)
    I_abstot: double;
    // Average angle of radiation in each class
    Bs1, Bs2, Bs3: double;

    Error: word;

    function I_0dif(Bs: double): double;
    function I_0dir(Bs: double): double;

    // Relative diffuse irradiance
    function I_dif(Bs, N, F_cum: double): double;
    // Relative scattered beam irradiance
    function I_scat(Bs, N, F_cum: double): double;
    // Relative direct beam irradiance
    function I_dir(Bs, N: double): double;
    // Fraction of sunlit leaves
    function f_sl(Bs, F_cum: double): double;

    // Total instantaneous photosynthesis
    function P_tot(Bs, N, F_cum: double): double;
    // Initialises Bs's to 15, 45 and 75 deg.
    constructor Create;
  end;

  TPlot = class(TPlot_p) // Main data class, incorporating lists of
    // Species, Subplots and Individuals
  public
    // Hash tables indexing the Object lists
    HTSpecies: THashTable;
    HTSubPlot: THashTable;
    HTIndividual: THashTable;
    // Objectlists of all species, subplots and individuals
    Species: TFPObjectList;
    Subplot: TFPObjectList;
    Individual: TFPObjectList;

    function ErrStr(Error: word): string;
    // Converts Error to an error message
    function declination(date: integer): double;
    // Sun declination
    //   doy as days from start of the year: jan 1st = 1
    function inclination(date: integer; time: double): double;
    // Sun inclination
    //   time in hours suntime -> highest point of sun is 12 o'clock
    function daylength(date: integer): double;
    // Length of the day, from sunrise to sunset

    constructor Create;
    destructor Destroy; override;
  end;

function deg2rad(degrees: double): double;
function rad2deg(radians: double): double;

implementation

uses Math, SysUtils;

{ TIndividual }

function TIndividual.M_air(Bs: double): double;
  // Air mass for radiation at an angle Bs to pass through
begin
  Result := sqrt(1229 + sqr(614 * sin(Bs))) - 614 * sin(Bs);
end;

function TIndividual.alpha(N: double): double;
begin
  if Plot.Alpha_const then
    Result := Plot.Alpha_veg
  else
  begin
    Result := Species.chl(N) / (Species.chl(N) + 76);
    // Prevent very low alpha values in case of low leaf nitrogen content
    if Result < 0.2 then
      Result := 0.2;
  end;
end;

function TIndividual.I_0dif(Bs: double): double;
begin
  if Plot.Overcast then
    Result := Plot.I_overcast
  else
    Result := Sc * (0.271 - 0.294 * power(tau, M_air(Bs))) * sin(Bs);
end;

function TIndividual.I_0dir(Bs: double): double;
begin
  if Plot.Overcast then
    Result := 0
  else
    Result := Sc * power(tau, M_air(Bs)) * sin(Bs);
end;

function TIndividual.f_sl(Bs, F_cum: double): double;
begin
  Result := exp(-k_bl(Bs) * F_cum);
end;

function TIndividual.I_dif(Bs, N, F_cum: double): double;
begin
  if (plot.k_veg_data and (subplot.K_veg <> 0)) then
    Result := I_0dif(Bs) * (1 - Plot.rho) * sqrt(Alpha(N)) * k_dif(F_cum) * exp(-subplot.K_veg * F_cum)
  else
    Result := I_0dif(Bs) * (1 - Plot.rho) * sqrt(Alpha(N)) * k_dif(F_cum) *
      exp(-subplot.k_dif(F_cum) * sqrt(Plot.alpha_veg) * F_cum);
end;

function TIndividual.I_dir(Bs, N: double): double;
begin
  Result := I_0dir(Bs) * k_bl(Bs) * Alpha(N);
end;

function TIndividual.I_scat(Bs, N, F_cum: double): double;
begin
  Result := I_0dir(Bs) * sqrt(Alpha(N)) * k_bl(Bs) * ((1 - Plot.rho) * exp(-Subplot.k_bl(Bs) *
    sqrt(Plot.alpha_veg) * F_cum) - sqrt(Alpha(N)) * exp(-Subplot.k_bl(Bs) * F_cum));
end;

function TIndividual.k_bl(Bs: double): double;
begin
  Result := (Species.f1 * O_av(Species.Bl1, Bs) + Species.f2 * O_av(Species.Bl2, Bs) + Species.f3 *
    O_av(Species.Bl3, Bs)) / sin(Bs);
end;

function TIndividual.k_dif(F_cum: double): double;
  // Extinction coefficient in diffuse light
begin
  Result := -Ln(Frac1 * Exp(-k_bl(Bs1) * F_cum) + Frac2 * Exp(-k_bl(Bs2) * F_cum) + Frac3 * Exp(-k_bl(Bs3) * F_cum)) / F_cum;
end;

function TIndividual.O_av(Bl, Bs: double): double;
  // Average projection of a leaf with angle Bl to radiation with angle Bs
begin
  if Bs < Bl then
    Result := 2 / pi * (sin(Bs) * cos(Bl) * arcsin(tan(Bs) / tan(Bl)) + sqrt(sqr(sin(Bs)) + sqr(sin(Bl))))
  else
    Result := sin(Bs) * cos(Bl);
end;

function TIndividual.P_tot(Bs, N, F_cum: double): double;
begin
  Result := f_sl(Bs, F_cum) * Species.P_l(I_dir(Bs, N) + I_scat(Bs, N, F_cum) + I_dif(Bs, N, F_cum), N) +
    (1 - f_sl(Bs, F_cum)) * Species.P_l(I_scat(Bs, N, F_cum) + I_dif(Bs, N, F_cum), N);
end;

constructor TIndividual.Create;
begin
  inherited;
  Bs1 := r15;
  Bs2 := r45;
  Bs3 := r75;
end;

{ TSpecies }

function TSpecies.Chl(N: double): double;
begin
  Result := (a_chl * N + b_chl) * c_chl / ((a_chl * N + b_chl) + c_chl);
end;

constructor TSpecies.Create;
begin
  inherited;
  Bl1 := r15;
  Bl2 := r45;
  Bl3 := r75;
  f_Rd := f_Rd_def;
end;

function TSpecies.P_l(I, N: double): double;
begin
  I := I * phi; // To make the following calculation easier to read
  Result := ((P_max(N) + I) - sqrt(sqr(P_max(N) + I) - (4 * theta * P_max(N) * I))) / (2 * theta) - R_d(N);
end;

function TSpecies.P_max(N: double): double;
begin
  if p_lin then  // Linear Pmax relation
    Result := a_P * N + b_P
  else           // Hyperbolic Pmax relation
    Result := (a_P * N + b_P) * c_P / ((a_P * N + b_P) + c_P);
end;

function TSpecies.R_d(N: double): double;
begin
  Result := a_R * N + b_R;
end;

{ TSubPlot }

function TSubPlot.AverageAngle: double;
begin
  Result := f1 * 15 + f2 * 45 + f3 * 75;
end;

constructor TSubPlot.Create;
begin
  inherited;
  Bl1 := r15;
  Bl2 := r45;
  Bl3 := r75;
  Bs1 := r15;
  Bs2 := r45;
  Bs3 := r75;
end;

procedure TSubPlot.InitLeafAngles(angle: double);
begin
  f1 := -1 / 60 * angle + 1.15;
  f2 := 0.2;
  f3 := 0.8 - f1;
end;

function TSubPlot.k_bl(Bs: double): double;
begin
  Result := (f1 * O_av(Bl1, Bs) + f2 * O_av(Bl2, Bs) + f3 * O_av(Bl3, Bs)) / sin(Bs);
end;

function TSubPlot.k_dif(F_cum_: double): double;
  // Extinction coefficient in diffuse light
begin
  Result := -Ln(Frac1 * Exp(-k_bl(Bs1) * F_cum_) + Frac2 * Exp(-k_bl(Bs2) * F_cum_) + Frac3 *
    Exp(-k_bl(Bs3) * F_cum_)) / F_cum_;
end;

function TSubPlot.O_av(Bl, Bs: double): double;
  // Average projection of a leaf with angle Bl to radiation with angle Bs
begin
  if Bs < Bl then
    Result := 2 / pi * (sin(Bs) * cos(Bl) * arcsin(tan(Bs) / tan(Bl)) + sqrt(sqr(sin(Bs)) + sqr(sin(Bl))))
  else
    Result := sin(Bs) * cos(Bl);
end;

{ TPlot }

function TPlot.declination(date: integer): double;
begin
  // 23.45 is dec. of tropic of cancer
  Result := -arcsin(sin(deg2rad(23.45)) * cos(2 * pi * (date + 10) / 365));
end;

function TPlot.inclination(date: integer; time: double): double;
var
  Dec: double;
begin
  Dec := declination(date);
  Result := arcsin(sin(latitude) * sin(Dec) + cos(latitude) * cos(Dec) * cos(2 * pi * (time - 12) / 24));
end;
// http://aa.usno.navy.mil/faq/docs/SunApprox.html
// http://xoomer.virgilio.it/vtomezzo/sunriset/formulas/algorythms.html

function TPlot.daylength(date: integer): double;
var
  Dec: double;
begin
  Dec := declination(date);
  Result := 12 * (1 + 2 * arcsin((sin(latitude) * sin(Dec)) / (cos(latitude) * cos(Dec))) / pi);
end;

constructor TPlot.Create;
begin
  inherited;
  HTSpecies := THashTable.Create;
  HTSubplot := THashTable.Create;
  HTIndividual := THashTable.Create;

  Species := TFPObjectList.Create;
  Species.OwnsObjects := True;
  Subplot := TFPObjectList.Create;
  Subplot.OwnsObjects := True;
  Individual := TFPObjectList.Create;
  Individual.OwnsObjects := True;
end;

destructor TPlot.Destroy;
begin
  FreeAndNil(HTSpecies);
  FreeAndNil(HTSubPlot);
  FreeAndNil(HTIndividual);
  FreeAndNil(Species);
  FreeAndNil(Subplot);
  FreeAndNil(Individual);
  inherited;
end;

{ TPlot_p }

constructor TPlot_p.Create;
begin
  inherited;
  alpha_const := False;
  k_veg_data := False;
  Overcast := False;
  I_overcast := I_overcast_def;
end;

function TPlot.ErrStr(Error: word): string;
begin
  Result := '';
  if Error and LE_Fvegzero = LE_Fvegzero then
    Result := 'Subplot layer LAI is 0, while plant layer LAI is not 0 ';
  //    if Error and LE_Fvegsmall = LE_Fvegsmall then
  //        Result:=Result+'Subplot layer LAI is smaller than plant layer LAI ';
  if Error and IE_NoSpecies = IE_NoSpecies then
  begin
    if Result <> '' then
      Result := Result + ' / ';
    Result := Result + 'No species data available ';
  end;
  if Error and IE_NoSubplot = IE_NoSubplot then
  begin
    if Result <> '' then
      Result := Result + ' / ';
    Result := Result + 'No subplot data available ';
  end;
  if Error and IE_HashCollision = IE_HashCollision then
  begin
    if Result <> '' then
      Result := Result + ' / ';
    Result := Result + 'Hash table collision (duplicate name?) ';
  end;
end;

function deg2rad(degrees: double): double; inline;
begin
  Result := degrees * (pi / 180);
end;

function rad2deg(radians: double): double; inline;
begin
  Result := radians / (pi / 180);
end;

end.
