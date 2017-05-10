# StratiPHOLIAGE
Stratified Photosynthesis and Light Absorption Model

## Details

StratiPHOLIAGE is a model that calculates light absorption and photosynthesis for trees in closed canopies.
For a full description, see the [model documentation](doc/StratiPHOLIAGE_model.pdf).

A related 3D model for trees in canopy gaps is [PHOLIAGE](https://github.com/rjoomen/PHOLIAGE).

### Literature

Studies that have used the model:

[Selaya _et al._, 2008.](https://www.researchgate.net/publication/227984851_Biomass_allocation_and_leaf_life_span_in_relation_to_light_interception_by_tropical_forest_plants_during_the_first_years_of_secondary_succession) Biomass allocation and leaf life span in relation to light interception by tropical forest plants during the first years of secondary succession

[Selaya _et al._, 2007.](https://www.researchgate.net/publication/6589975_Above-ground_Biomass_Investments_and_Light_Interception_of_Tropical_Forest_Trees_and_Lianas_Early_in_Succession) Above-ground Biomass Investments and Light Interception of Tropical Forest Trees and Lianas Early in Succession

## Implementation details

### Lazarus / Delphi

The original version was written in Delphi. This is the version ported to Lazarus / FPC.

Main changes
- Supports multiple platforms (Linux, Windows, and macOS).
- Reads *.xls, *.xlsx, and *.ods files natively (previous version used Windows-only Excel OLE automation).
- Diagnostic graphing in tab 'Results' has been removed (too much work to port).
- Removed Windows/Delphi-specific multithreading code (too much work to port).

For further details, see the changelog.

### Numerical differences between versions

Model result differ slightly between Linux/Win32 builds and Win64 builds. The Linux/Win32 results are exactly the same as the results from the last Delphi version (2.0.1). The reason results on Win64 are different is that on Win64 the 80-bit floating point _Extended_ datatype is not supported. The Math unit therefore internally uses Double (64 bit) instead of Extended, leading to minute differences. This is no problem, the loss in precision is negligible, and the StratiPHOLIAGE model itself uses Double for all calculations anyway. For details see for example [this forum post](http://forum.lazarus.freepascal.org/index.php?topic=29678.0), and the source code of the Math unit.

## Running

Binary releases are available under the [releases tab](https://github.com/rjoomen/StratiPHOLIAGE/releases).

The [model documentation](doc/StratiPHOLIAGE_model.pdf) has some hints on program usage.

## Compiling/Modifying

1. Install [Lazarus](https://www.lazarus-ide.org/)
2. Install [FPSpreadSheet](http://wiki.freepascal.org/FPSpreadsheet)
3. Check out the sources ('Clone or download' button above)
4. Open project file `StratiPHOLIAGE.lpi` in Lazarus and press F9 to run.
