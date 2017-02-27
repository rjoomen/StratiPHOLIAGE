unit UExcel;

{$MODE objfpc}{$H+}

// Native methods for writing a simple Excel file
// Based on source by Fatih Olcer published in this article:
//   http://www.swissdelphicenter.ch/en/showcode.php?id=725

interface

uses
  Classes, SysUtils;

type
  WriteXLS = class
  private
    XLSStream: TFileStream;
    procedure XlsBeginStream(_XlsStream: TStream; const BuildNumber: word);
    procedure XlsEndStream(_XlsStream: TStream);
  public
    function xlsopen(filename: string): boolean;
    procedure xlsclose;

    // Integer
    procedure XlsWriteCellRk(const ACol, ARow: word;
      const AValue: integer);
    // Floating point number
    procedure XlsWriteCellNumber(const ACol, ARow: word;
      const AValue: double);
    // String
    procedure XlsWriteCellLabel(const ACol, ARow: word;
      const AValue: ansistring);
  end;


implementation

var
  CXlsBof: array[0..5] of word = ($809, 8, 00, $10, 0, 0);
  CXlsEof: array[0..1] of word = ($0A, 00);
  CXlsLabel: array[0..5] of word = ($204, 0, 0, 0, 0, 0);
  CXlsNumber: array[0..4] of word = ($203, 14, 0, 0, 0);
  CXlsRk: array[0..4] of word = ($27E, 10, 0, 0, 0);

procedure WriteXLS.XlsBeginStream(_XlsStream: TStream; const BuildNumber: word);
begin
  CXlsBof[4] := BuildNumber;
  _XlsStream.WriteBuffer(CXlsBof, SizeOf(CXlsBof));
end;

procedure WriteXLS.XlsEndStream(_XlsStream: TStream);
begin
  _XlsStream.WriteBuffer(CXlsEof, SizeOf(CXlsEof));
end;

procedure WriteXLS.XlsWriteCellRk(const ACol, ARow: word; const AValue: integer);
var
  V: integer;
begin
  CXlsRk[2] := ARow;
  CXlsRk[3] := ACol;
  XlsStream.WriteBuffer(CXlsRk, SizeOf(CXlsRk));
  V := (AValue shl 2) or 2;
  XlsStream.WriteBuffer(V, 4);
end;

procedure WriteXLS.XlsWriteCellNumber(const ACol, ARow: word; const AValue: double);
begin
  CXlsNumber[2] := ARow;
  CXlsNumber[3] := ACol;
  XlsStream.WriteBuffer(CXlsNumber, SizeOf(CXlsNumber));
  XlsStream.WriteBuffer(AValue, 8);
end;

procedure WriteXLS.XlsWriteCellLabel(const ACol, ARow: word; const AValue: ansistring);
var
  L: word;
begin
  L := Length(AValue);
  CXlsLabel[1] := 8 + L;
  CXlsLabel[2] := ARow;
  CXlsLabel[3] := ACol;
  CXlsLabel[5] := L;
  XlsStream.WriteBuffer(CXlsLabel, SizeOf(CXlsLabel));
  XlsStream.WriteBuffer(Pointer(AValue)^, L);
end;

function WriteXLS.xlsopen(filename: string): boolean;
begin
  XlsStream := TFileStream.Create(filename, fmCreate);
  try
    XlsBeginStream(XlsStream, 0);
    Result := True;
  except
    FreeAndNil(XlsStream);
    Result := False;
  end;
end;

procedure WriteXLS.xlsclose;
begin
  XlsEndStream(XlsStream);
  FreeAndNil(XlsStream);
end;

end.
