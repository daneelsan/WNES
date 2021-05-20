Package["NES`"]

PackageImport["GeneralUtilities`"]

PackageScope["$libNESAvailable"]
PackageScope["unloadLibrary"]
PackageScope["importLibNESFunction"]

(* All functions loaded from C++ should go in this file. This is the counterpart of libNES/NES.hpp *)

(* this function is defined now, but only run the *next* time Kernel/init.m is called, before all symbols
are cleared. *)
unloadLibrary[] := If[StringQ[$libraryFile],
  Scan[LibraryFunctionUnload, $libraryFunctions];
  $libraryFunctions = Null;
  Quiet @ LibraryUnload[$libraryFile];
];

NES::nolibNES = "libNES (``) could not be found.";

$libraryFile = $NESLibraryPath;

If[!StringQ[$libraryFile] || !FileExistsQ[$libraryFile],
  Message[NES::nolibNES, $libraryFile];
  $libraryFile = $Failed;
];

$libraryFunctions = {};

$cppRedistributableURL =
  "https://support.microsoft.com/en-us/topic/" <>
  "the-latest-supported-visual-c-downloads-2647da03-1eea-4433-9aff-95f26a218cc0";

NES::cppRedistributable =
  "Check that " <>
  "\!\(\*TemplateBox[" <>
    "{\"Microsoft Visual C++ Redistributable\", " <>
    "{URL[\"" <> $cppRedistributableURL <> "\"], None}, " <>
    "\"" <> $cppRedistributableURL <> "\", " <>
    "\"HyperlinkActionRecycled\", " <>
    "{\"HyperlinkActive\"}, " <>
    "BaseStyle -> {\"URL\"}, " <>
    "HyperlinkAction -> \"Recycled\"}, " <>
    "\"HyperlinkTemplate\"]\)" <>
  " is installed.";

importLibNESFunction[cppFunctionName_ -> symbol_, argumentTypes_, outputType_] := (
  symbol = If[$libraryFile =!= $Failed,
    Check[
      LibraryFunctionLoad[$libraryFile, cppFunctionName, argumentTypes, outputType]
    ,
      If[$SystemID === "Windows-x86-64", Message[NES::cppRedistributable]];
      $Failed
    ,
      {LibraryFunction::libload}
    ]
  ,
    $Failed
  ];
  AppendTo[$libraryFunctions, symbol];
);

$libNESAvailable := FreeQ[$libraryFunctions, $Failed];
