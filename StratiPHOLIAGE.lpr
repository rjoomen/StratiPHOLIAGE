program StratiPHOLIAGE;

{$MODE objfpc}{$H+}

uses
  Forms,
  Interfaces,
  User_int in 'User_int.pas' {Form1},
  Data_defs in 'Data_defs.pas',
  Data_RW in 'Data_RW.pas',
  Calc in 'Calc.pas',
  Uhashtable in 'Uhashtable.pas',
  GaussInt in 'GaussInt.pas',
  UExcel in 'UExcel.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

