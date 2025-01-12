Package["NESDevUtils`"]

PackageImport["GeneralUtilities`"]

PackageExport["PackNES"]

Options[PackNES] = {
  "RepositoryDirectory" :> $NESRoot, (* for Git SHAs etc *)
  "SourceDirectory" -> Automatic, (* for WL sources *)
  "LibraryDirectory" -> Automatic, (* for libNES *)
  "MasterBranch" -> "main", (* for calculating the minor version *)
  "OutputDirectory" -> Automatic,
  "Verbose" -> False
};

PackNES::nosources = "There were no .m files in ``.";
PackNES::nolibraries = "There were no library files in ``.";
PackNES::packfailed = "Could not pack paclet from `` into ``.";
PackNES::nopacletinfo = "Paclet info file was not present at ``.";
PackNES::nobuildinfo = "Build info file was not present at ``.";
PackNES::nogitlink = "GitLink is not installed, so the built paclet version cannot be correctly \
calculated. Proceed with caution, and consider installing GitLink by running InstallGitLink[].";

SyntaxInformation[PackNES] =
  {"ArgumentsPattern" -> {OptionsPattern[]}, "OptionNames" -> Options[PackNES][[All, 1]]};

SetUsage @ "
PackNES[] creates a PacletObject containing the local source and last built library.
* Note that PackNES[] does *not* call BuildLibNES[], unlike the command line scripts.
* The PacletObject represents a .paclet file created on disk.
* 'RepositoryDirectory' defaults to the repository containing DevUtils, but can be set to another directory.
* 'RepositoryDirectory' must be a Git repo, and will be used to obtain the Git SHA hash and minor version number.
* The default location of the .paclet file is within the BuiltPaclets subdirectory of the 'RepositoryDirectory', \
but that can be overriden with the 'OutputDirectory' option.
* The Wolfram Language sources for the paclet are taken from the Kernel subdirectory of 'SourceDirectory'.
* The built libNES libraries are taken from the LibraryResources subdirectory of 'LibraryDirectory'.
* 'SourceDirectory' and 'LibraryDirectory' default to the value of 'RepositoryDirectory'.
* The minor version is derived from the number of commits between the last checkpoint and the 'master' branch,
which can be overriden with the 'MasterBranch' option. The checkpoint is defined in `scripts/version.wl`. The \
git repo is assumed to live at 'RepositoryDirectory'.
* Setting 'Verbose' to True will Print information about the progress of the pack.
";

PackNES[opts : OptionsPattern[]] := Module[{
    sourceDir, libDir, repositoryDir, masterBranch, outputDir, verbose,
    minorVersionNumber, pacletInfoFile, gitSHA, buildInfo, tempBuildInfoFile,
    kernelDir, libraryDir, fileInputs, pacletCreatorFunction, pacletFileName
  },

  {repositoryDir, sourceDir, libDir, masterBranch, outputDir, verbose} =
    OptionValue[
      PackNES,
      {opts},
      {"RepositoryDirectory", "SourceDirectory", "LibraryDirectory", "MasterBranch", "OutputDirectory", "Verbose"}];

  SetAutomatic[outputDir, FileNameJoin[{repositoryDir, "BuiltPaclets"}]];
  SetAutomatic[libDir, repositoryDir];
  SetAutomatic[sourceDir, repositoryDir];
  EnsureDirectory[outputDir];

  If[$GitLinkAvailableQ,
    minorVersionNumber = CalculateMinorVersionNumber[repositoryDir, masterBranch];
    pacletInfoFile = createUpdatedPacletInfo[FileNameJoin[{sourceDir, "PacletInfo.m"}], minorVersionNumber];
    gitSHA = GitSHAWithDirtyStar[repositoryDir];
  ,
    Message[PackNES::nogitlink];
    pacletInfoFile = FileNameJoin[{sourceDir, "PacletInfo.m"}];
    gitSHA = Missing["GitLinkNotAvailable"];
  ];

  buildInfo = <|"GitSHA" -> gitSHA, "BuildTime" -> Round[DateList[TimeZone -> "UTC"]]|>;
  tempBuildInfoFile = FileNameJoin[{$DevUtilsTemporaryDirectory, "PacletBuildInfo.json"}];
  Developer`WriteRawJSONFile[tempBuildInfoFile, buildInfo];

  kernelDir = FileNameJoin[{sourceDir, "Kernel"}];
  libraryDir = FileNameJoin[{libDir, "LibraryResources"}];
  If[Length[FileNames["*.m", kernelDir]] == 0, ReturnFailed["nosources", kernelDir]];
  If[Length[FileNames[All, libraryDir, 2]] == 0, ReturnFailed["nolibraries", libraryDir]];
  If[!FileExistsQ[pacletInfoFile], ReturnFailed["nopacletinfo", pacletInfoFile]];
  If[!FileExistsQ[tempBuildInfoFile], ReturnFailed["nobuildinfo", tempBuildInfoFile]];

  fileInputs = {kernelDir, libraryDir, pacletInfoFile, tempBuildInfoFile};

  pacletCreatorFunction = If[$VersionNumber >= 12.1,
    Symbol["System`CreatePacletArchive"]
  ,
    Symbol["PacletManager`PackPaclet"]
  ];
  pacletFileName = pacletCreatorFunction[fileInputs, outputDir];

  If[StringQ[pacletFileName],
    If[verbose,
      Print["Paclet file written to ", pacletFileName]
    ];
    Return @ If[$VersionNumber >= 12.1, PacletObject[File[pacletFileName]], <|"Location" -> pacletFileName|>]
  ,
    If[verbose, Print["Pack failed."]];
    ReturnFailed["packfailed", sourceDir, outputDir]
  ]
];

createUpdatedPacletInfo[pacletInfoFilename_, minorVersionNumber_] :=
  Module[{pacletInfo, versionString, tempFilename},
    pacletInfo = Association @@ Import[pacletInfoFilename];
    versionString = pacletInfo[Version] <> "." <> ToString[minorVersionNumber];
    tempFilename = FileNameJoin[{$DevUtilsTemporaryDirectory, "PacletInfo.m"}];
    AppendTo[pacletInfo, Version -> versionString];
    Block[{$ContextPath = {"System`", "PacletManager`"}},
      Export[tempFilename, PacletManager`Paclet @@ Normal[pacletInfo]]
    ];
    tempFilename
  ];
