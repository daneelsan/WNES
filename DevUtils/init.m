Package["NESDevUtils`"]

(* NESDevUtils is *not* included in paclet builds, so is not visible to users,
but is available for developer workflow purposes, and is used by the build scripts *)

PackageImport["GeneralUtilities`"]

PackageExport["$NESRoot"]
PackageExport["$DevUtilsRoot"]
PackageExport["$DevUtilsTemporaryDirectory"]

SetUsage @ "
$NESRoot is the directory from which NES was loaded.
";

$NESRoot = FileNameDrop[$InputFileName, -2];

SetUsage @ "
$DevUtilsRoot is the directory from which the DevUtils package was loaded.
";

$DevUtilsRoot = FileNameDrop[$InputFileName, -1];

SetUsage @ "
$DevUtilsTemporaryDirectory is the temprary directory that DevUtils uses.
";

$DevUtilsTemporaryDirectory := EnsureDirectory @ FileNameJoin[{$TemporaryDirectory, "NES"}];
