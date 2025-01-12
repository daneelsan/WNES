Unprotect["NES`*"];

(* this is a no-op the first time round, subsequent loads will unload the C++ library first *)
NES`PackageScope`unloadLibrary[];

ClearAll @@ (# <> "*" & /@ Contexts["NES`*"]);

(* Make sure that we don't affect $ContextPath by getting GU, and that we are isolated from
any user contexts *)
BeginPackage["NES`"];

(* This is useful for various purposes, like loading libraries from the 'same place' as the
paclet, and also knowing *where* the loaded code even came from. *)
$NESRootDirectory = FileNameDrop[$InputFileName, -2];

Needs["GeneralUtilities`"];

(* ensure private symbols we use below don't show up on Global, etc *)
Begin["NES`Private`"];

Block[
  (* Temporarily overrule some of the more exotic features of the macro system. *)
  {GeneralUtilities`Control`PackagePrivate`$DesugaringRules = {}},
  (* All files are loaded lexicographically starting with A0*. Note, "$" comes after "A" in Wolfram Language.
     File names starting with digits are not allowed. "_" and "-" are not allowed. *)
  Get[First[FileNames["*", FileNameJoin[{$NESRootDirectory, "Kernel"}]]]];
];

End[];

EndPackage[];

SetAttributes[#, {Protected, ReadProtected}] & /@ Evaluate @ Names @ "NES`*";
