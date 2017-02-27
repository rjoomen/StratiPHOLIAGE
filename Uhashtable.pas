unit Uhashtable;

{$MODE objfpc}{$H+}

(*
*  Hashtable Unit - unknown author
*   Uses ELF hash algorithm to convert a string to a hash value
*
*  RJO: Added collision detection - no handling, only warning.
*)

interface

type
  PHashRec = ^THashRec;

  THashRec = record
    Next: PHashRec;
    hash: int64;
    index: integer;
  end;

  THashTable = class
    table: PHashRec;
    collisiondetection: boolean;

    constructor Create;

    function ELFHash(const Value: string): int64;

    function DeleteHash(hash: int64): integer;
    function InsertHash(hash: int64; index: integer): boolean;
    // If false is returned a collision was detected

    function GetStrIndex(element: string): integer;
    function GetIndex(hash: int64): integer;

    destructor Destroy; override;
  end;

implementation

// Hash function: converts string to hash value
function THashTable.ELFHash(const Value: string): int64;
var
  i: integer;
  x: int64;
begin
  Result := 0;
    {$R-}// Range check off
  for i := 1 to Length(Value) do
  begin
    Result := (Result shl 4) + Ord(Value[i]);
    x := Result and $F0000000;
    if (x <> 0) then
      Result := Result xor (x shr 24);
    Result := Result and (not x);
  end;
    {$R+}
end;

constructor THashTable.Create;
begin
  inherited;
  table := nil;
  collisiondetection := True;
end;


// DeleteHash locates an element in the list, fixes the list pointers so
// that this element is no longer referenced, releases the memory for
// the element, and returns the element's index.

function THashTable.DeleteHash(hash: int64): integer;
var
  P, Q: PHashRec;
begin
  P := Table;
  Q := nil;
  while (P <> nil) and (P^.hash <> hash) do
  begin
    Q := P;
    P := P^.Next;
  end;
  if P <> nil then
  begin
    Result := P^.index;
    if Q = nil then
      Table := P^.Next
    else
      Q^.Next := P^.Next;
    Dispose(P);
  end
  else
    Result := 0;
end;


// InsertHash adds an element to the head (beginning) of the list
// New(P) allocates memory on the stack

function THashTable.InsertHash(hash: int64; index: integer): boolean;
var
  P: PHashRec;
begin
  if collisiondetection then
    Result := (GetIndex(hash) = -1) // Check if hash already is in table
  else
    Result := True;
  New(P);
  P^.Next := Table;
  P^.hash := hash;
  P^.index := index;
  Table := P;
end;


function THashTable.GetStrIndex(element: string): integer;
begin
  Result := GetIndex(ELFHash(element));
end;

// GetIndex walks the list using P := P^.Next
// Notice that hash does not refer to a position in the list,
// instead, it refers to a value stored in the list element (record of
// type THashRec)

function THashTable.GetIndex(hash: int64): integer;
var
  P: PHashRec;
begin
  P := Table;
  while (P <> nil) and (P^.hash <> hash) do
    P := P^.Next;
  if P = nil then
    Result := -1
  else
    Result := P^.index;
end;

destructor THashTable.Destroy;
var
  P, Q: PHashRec;
begin
  p := table;
  while p <> nil do
  begin
    q := p^.Next;
    dispose(p);
    p := q;
  end;
  inherited;
end;

end.
