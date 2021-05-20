Package["NES`"]

PackageScope["hexFormat"]
PackageScope["binFormat"]
PackageScope["commentFormat"]

hexFormat[n_Integer, b_ : (1 | 2)] := ToUpperCase[IntegerString[n, 16, b * 2]];

binFormat[n_Integer, b : (1 | 2) : 1] := IntegerString[n, 2, b * 8];

commentFormat[a_, b_] := Row[{a, Style[Row[{" (", b, ")"}], Gray]}];
