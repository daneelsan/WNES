Package["NESDevUtils`"]

PackageImport["GeneralUtilities`"]

PackageExport["BuildLibNES"]

Options[BuildLibNES] = {
  "RepositoryDirectory" :> $NESRoot,
  "LibrarySourceDirectory" -> Automatic,
  "LibraryTargetDirectory" -> Automatic,
  "SystemID" -> $SystemID,
  "Compiler" -> Automatic,
  "CompilerInstallation" -> Automatic,
  "WorkingDirectory" -> Automatic,
  "LoggingFunction" -> None,
  "PreBuildCallback" -> None,
  "Caching" -> True,
  "Verbose" -> False
};

SyntaxInformation[BuildLibNES] = {
  "ArgumentsPattern" -> {OptionsPattern[]},
  "OptionNames" -> Options[BuildLibNES][[All, 1]]
};

SetUsage @ "
BuildLibNES[] builds the libNES library from source, and returns an association of metadata \
on completion, or $Failed if the library could not be built.
* By default, the resulting library is placed within the appropriate system-specific subdirectory of the \
'LibraryResources' directory of the current repo, but this location can be overriden with the \
'LibraryTargetDirectory' option.
* By default, the sources are obtained from the 'libNES' subdirectory of the current repo, but this \
location can be overriden with the 'LibrarySourceDirectory' option.
* The meaning of 'current repo' for the above two options is set by the 'RepositoryDirectory' option, which \
defaults to the root of the repo containing the DevUtils package.
* Additional metadata is written to 'LibraryTargetDirectory' in a file called 'libNESBuildInfo.json'.
* The library file name includes a hash based on the library and build utility sources.
* If the library target directory fills up with more than 128 files, the least recently generated files \
will be automatically deleted.
* If a library file with the appropriate hashes already exists, the build step is skipped, but the build \
metadata is still written to a json file in the 'LibraryTargetDirectory'.
* Various compiler options can be specified with 'Compiler', 'CompilerInstallation', 'WorkingDirectory', \
and 'LoggingFunction'.
* Setting 'PreBuildCallback' to a function will call this function prior to build happening, but only \
if a build is actually required. This is useful for printing a message in this case. This function is \
given the keys containing relevant build information.
* Setting 'Caching' to False can be used to prevent the caching mechanism from being applied.
* Setting 'Verbose' to True will Print information about the progress of the build.
";

BuildLibNES::compfail = "Compilation of C++ code at `` failed.";
BuildLibNES::badsourcedir = "Source directory `` did not exist.";

BuildLibNES[opts : OptionsPattern[]] := Module[{
    repositoryDir, libSourceDir, libTargetDir, systemID, compiler, compilerInstallation,
    workingDir, loggingFunction, preBuildCallback, caching, verbose,
    buildDataPath, sourceHashes, hashedOptions, finalHash, libFileName, libPath,
    calculateBuildData, buildData, fileNames
  },

  (* options processing *)
  {
    repositoryDir, libSourceDir, libTargetDir,
    systemID, compiler, compilerInstallation, workingDir,
    loggingFunction, preBuildCallback, caching, verbose
  } = OptionValue[
    BuildLibNES,
    {opts},
    {
      "RepositoryDirectory", "LibrarySourceDirectory", "LibraryTargetDirectory",
      "SystemID", "Compiler", "CompilerInstallation", "WorkingDirectory",
      "LoggingFunction", "PreBuildCallback", "Caching", "Verbose"
    }];

  SetAutomatic[compiler, ToExpression @ ConsoleTryEnvironment["COMPILER", Automatic]];
  SetAutomatic[compilerInstallation, ConsoleTryEnvironment["COMPILER_INSTALLATION", Automatic]];
  SetAutomatic[libSourceDir, FileNameJoin[{repositoryDir, "libNES"}]];
  SetAutomatic[libTargetDir, FileNameJoin[{repositoryDir, "LibraryResources", systemID}]];

  (* path processing *)
  buildDataPath = FileNameJoin[{libTargetDir, "libNESBuildInfo.json"}];
  libSourceDir = AbsoluteFileName[libSourceDir];
  If[FailureQ[libSourceDir], ReturnFailed["badsourcedir", libSourceDir]];

  (* derive hashes *)
  sourceHashes = Join[
    FileTreeHashes[libSourceDir, {"*.cpp", "*.hpp"}, 1],
    FileTreeHashes[$DevUtilsRoot, {"*.m"}, 1]
  ];
  hashedOptions = {compiler, compilerInstallation, systemID};
  finalHash = Hash[{sourceHashes, hashedOptions}, "Expression", "Base36String"];

  (* derive final paths *)
  libFileName = StringJoin["libNES-", finalHash, ".", System`Dump`LibraryExtension[]];
  libPath = FileNameJoin[{libTargetDir, libFileName}];

  calculateBuildData[] := <|
    "LibraryPath" -> libPath,
    "LibraryFileName" -> libFileName,
    "LibraryBuildTime" -> Round[DateList[FileDate[libPath], TimeZone -> "UTC"]],
    "LibrarySourceHash" -> finalHash
  |>;

  (* if a cached library exists with the right name, we can skip the compilation step, and need
  only write the JSON file *)
  If[caching && FileExistsQ[libPath] && FileExistsQ[buildDataPath],
    buildData = readBuildData[buildDataPath];

    (* the JSON file might already be correct, in which case don't write to at all *)
    If[buildData["LibraryFileName"] === libFileName,
      PrependTo[buildData, "LibraryPath" -> libPath];
    ,
      buildData = calculateBuildData[];
      writeBuildData[buildDataPath, buildData];
    ];
    buildData["FromCache"] = True;
    If[verbose, Print["Using cached library at ", libPath]];
    Return[buildData];
  ];

  (* prevent too many libraries from building up in the cache *)
  If[caching, flushLibrariesIfFull[libTargetDir]];

  (* if user gave a callback, call it now with relevant info *)
  If[verbose && preBuildCallback === None, preBuildCallback = "Print"];
  If[preBuildCallback =!= None,
    If[preBuildCallback === "Print", preBuildCallback = $printPreBuildCallback];
    preBuildCallback[<|
      "LibrarySourceDirectory" -> libSourceDir,
      "LibraryFileName" -> libFileName
    |>]
  ];

  fileNames = FileNames["*.cpp", libSourceDir];
  libPath = wrappedCreateLibrary[
      fileNames,
      libFileName,
      "CleanIntermediate" -> True,
      "CompileOptions" -> $compileOptions,
      "Compiler" -> compiler,
      "CompilerInstallation" -> compilerInstallation,
      "Language" -> "C++",
      "ShellCommandFunction" -> loggingFunction,
      "ShellOutputFunction" -> loggingFunction,
      "TargetDirectory" -> libTargetDir,
      "TargetSystemID" -> systemID,
      "WorkingDirectory" -> workingDir,
      "TransferProtocolLibrary" -> "WSTP"
  ];

  If[!StringQ[libPath],
    Message[BuildLibNES::compfail, libSourceDir];
    If[verbose, Print["Build failed"]];
    ReturnFailed[];
  ];
  If[verbose,
    Print["Library compiled to ", libPath]
  ];

  buildData = calculateBuildData[];
  writeBuildData[buildDataPath, buildData];
  buildData["FromCache"] = False;
  buildData
];

$printPreBuildCallback = Function[Print["Building libNES from sources in ", #LibrarySourceDirectory]];

readBuildData[jsonFile_] :=
  Developer`ReadRawJSONFile[jsonFile];

writeBuildData[jsonFile_, buildData_] :=
  Developer`WriteRawJSONFile[
    jsonFile,
    KeyDrop[buildData, {"LibraryPath", "FromCache"}],
    "Compact" -> 1
  ];

(* avoids loading CCompilerDriver until it is actually used *)
wrappedCreateLibrary[args___] := Block[{$ContextPath},
  Needs["CCompilerDriver`"];
  CCompilerDriver`CreateLibrary[args]
];

$warningsFlags = {
  "-Wall", "-Wextra", (* "-Werror", *)"-pedantic", "-Wcast-align", "-Wcast-qual", "-Wctor-dtor-privacy",
  "-Wdisabled-optimization", "-Wformat=2", "-Winit-self", "-Wmissing-include-dirs",
  "-Woverloaded-virtual", "-Wredundant-decls", "-Wshadow", "-Wsign-promo", "-Wswitch-default", (* "-Wundef", *)
  "-Wno-unused",

  (* "-Wold-style-cast" *) "-Wno-old-style-cast"
};

$compileOptions = Switch[$OperatingSystem,
  "Windows",
    {"/std:c++17", "/EHsc"},
  "MacOSX",
    Join[{"-std=c++17"}, $warningsFlags],
  "Unix",
    Join[{"-std=c++17"}, $warningsFlags]
];

flushLibrariesIfFull[libraryDirectory_] := Module[{files, oldestFile},
  files = FileNames["lib*", libraryDirectory];
  If[Length[files] > 127,
    oldestFile = MinimalBy[files, FileDate, 8];
    Scan[DeleteFile, oldestFile]
  ]
];
