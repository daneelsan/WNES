Package["NES`"]

PackageImport["GeneralUtilities`"]

PackageExport["$NESLibraryBuildTime"]
PackageExport["$NESLibraryPath"]
PackageExport["$NESBuildTime"]
PackageExport["$NESGitSHA"]

PackageScope["$packageRoot"]

$packageRoot = FileNameDrop[$InputFileName, -2];

NES::jitbuildfail = "Failed to (re)build libNES. The existing library, if any, will be used instead.";

(* before loading build data, we check if we are running on a developer's machine, indicated by
the presence of the DevUtils sub-package, if so, we load it and do a rebuild, so that we can
get up-to-date versions of the various build properties *)
$devUtilsPath = FileNameJoin[{$packageRoot, "DevUtils", "init.m"}];
If[FileExistsQ[$devUtilsPath],
  Block[{$ContextPath = {"System`"}}, Get[$devUtilsPath]];

  (* forwarders for the functions we want from DevUtils. This is done so
  we don't create the NESDevUtils context for ordinary users (when DevUtils *isn't* available) *)
  buildLibNES = Symbol["NESDevUtils`BuildLibNES"];
  gitSHAWithDirtyStar = Symbol["NESDevUtils`GitSHAWithDirtyStar"];

  (* try build the C++ code immediately (which will most likely retrieve a cached library) *)
  (* if there is a frontend, then give a temporary progress panel, otherwise just Print *)
  If[TrueQ @ $Notebooks,
    (* WithLocalSettings will run the final 'cleanup' argument even if the evaluation of the second
    argument aborts (due to a Throw, user abort, etc.) *)
    Internal`WithLocalSettings[
      $progCell = None;
    ,
      $buildResult = buildLibNES["PreBuildCallback" -> Function[
        $progCell = PrintTemporary @ Panel[
          "Building libNES from sources in " <> #LibrarySourceDirectory,
          Background -> LightOrange]]];
    ,
      NotebookDelete[$progCell];
      $progCell = None;
    ];
  ,
    $buildResult = buildLibNES["PreBuildCallback" -> "Print"];
  ];

  If[!AssociationQ[$buildResult],
    Message[NES::jitbuildfail];
  ];
];

readJSONFile[file_] := Quiet @ Check[Developer`ReadRawJSONFile[file], $Failed];

SetUsage @ "
$NESLibraryBuildTime gives the date object at which this C++ libNES library was built.
";

SetUsage @ "
$NESLibraryPath stores the path of the C++ libNES library.
";

$libraryDirectory = FileNameJoin[{$packageRoot, "LibraryResources", $SystemID}];
$libraryBuildDataPath = FileNameJoin[{$libraryDirectory, "libNESBuildInfo.json"}];

$buildData = readJSONFile[$libraryBuildDataPath];
If[$buildData === $Failed,
  $NESLibraryBuildTime = $NESLibraryPath = Missing["LibraryBuildDataNotFound"];
,
  $NESLibraryBuildTime = DateObject[$buildData["LibraryBuildTime"], TimeZone -> "UTC"];
  $NESLibraryPath = FileNameJoin[{$libraryDirectory, $buildData["LibraryFileName"]}];
];

SetUsage @ "
$NESBuildTime gives the time at which this NES paclet was built.
* When evaluated for an in-place build, this time is the time at which NES was loaded.
";

SetUsage @ "
$NESGitSHA gives the Git SHA of the repository from which this SetRepace paclet was built.
* When evaluated for an in-place build, this is simply the current HEAD of the git repository.
";

$pacletBuildInfoPath = FileNameJoin[{$packageRoot, "PacletBuildInfo.json"}];

If[FileExistsQ[$pacletBuildInfoPath] && AssociationQ[$pacletBuildInfo = readJSONFile[$pacletBuildInfoPath]],
  $NESBuildTime = DateObject[$pacletBuildInfo["BuildTime"], TimeZone -> "UTC"];
  $NESGitSHA = $pacletBuildInfo["GitSHA"];
,
  $NESGitSHA = gitSHAWithDirtyStar[$packageRoot];
  If[!StringQ[$NESGitSHA], Missing["GitLinkNotAvailable"]];
  $NESBuildTime = DateObject[TimeZone -> "UTC"];
];
