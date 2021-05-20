Package["NES`"]

PackageExport["M6502"]

(* libNES *)

importLibNESFunction[
  "M6502_getState" -> m6502$getState,
  LinkObject,
  LinkObject
];

importLibNESFunction[
  "M6502_setState" -> m6502$setState,
  {
    Integer,  (* Object Id            *)
    Integer,  (* PC: Program Counter  *)
    Integer,  (*  A: Accumulator      *)
    Integer,  (*  X: Index Register X *)
    Integer,  (*  Y: Index Register Y *)
    Integer,  (*  S: Stack Pointer    *)
    Integer   (*  P: Process Status   *)
  },
  "Boolean"   (* True if successful   *)
];

importLibNESFunction[
  "M6502_tick" -> m6502$tick,
  {
    Integer,  (* Object Id         *)
    Integer   (* Input Pins (u64)  *)
  },
  Integer     (* Output Pins (u64) *)
];

(* M6502Q *)

M6502Q[obj_M6502] := ManagedLibraryExpressionQ[obj, "M6502"];
M6502Q[_] = False;

(* Create *)

M6502Create[] :=
  Module[{obj},
    obj = CreateManagedLibraryExpression["M6502", M6502];
    obj
  ];

(* Normal *)

M6502 /: Normal[obj_M6502 ? M6502Q] := m6502$getState[obj["InstanceID"]];

(* Properties *)

HoldPattern[(obj : M6502[id_]) ? M6502Q][prop___] := m6502PropertyDispatch[obj, prop];

$m6502InstanceProperties = {
  "Properties",
  "InstanceID"
};

(** "Properties" **)

m6502PropertyDispatch[obj_, "Properties"] :=
  Sort @ $m6502InstanceProperties;

(** "InstanceID" **)

m6502PropertyDispatch[obj_, "InstanceID"] :=
  ManagedLibraryExpressionID[obj, "M6502"];

(** "ProcessStatusRegister" **)

processStatusRegisterFormat[p_] := Row @ MapThread[
  Framed[#1, FrameStyle -> If[#2 === 1, Bold, LightGray]] &,
  {{"N", "V", " ", "B", "D", "I", "Z", "C"}, IntegerDigits[p, 2, 8]}
];

m6502PropertyDispatch[obj_, "ProcessStatusRegister", "Visualization"] :=
  processStatusRegisterFormat[m6502PropertyDispatch[obj, "ProcessStatusRegister"]];

(** Failure **)

m6502PropertyDispatch[obj_, prop_, args___] /; MemberQ[$m6502InstanceProperties, prop] :=
  Failure["M6502",
    <|
      "MessageTemplate" -> "Unrecognized arguments `args` for the property \"`prop`\".",
      "MessageParameters" -> <|"prop" -> prop, "args" -> {args}|>,
      "Input" -> {args}
    |>
  ];

m6502PropertyDispatch[obj_, prop_, args___] :=
  Failure["M6502",
    <|
      "MessageTemplate" -> "Unrecognized property `prop`. See \"Properties\" for a list of available properties.",
      "MessageParameters" -> <|"prop" -> prop|>,
      "Input" -> prop
    |>
  ];

(* SummaryBox *)

M6502 /: MakeBoxes[obj_M6502 ? M6502Q, fmt_] :=
  Module[{id, state, regs, pins, extra, alwaysVisible, sometimesVisible},
    id = obj["InstanceID"];
    state = Normal[obj];

    regs = state["Register"];
    pins = state["Pin"];
    extra = state["Extra"];

    alwaysVisible = Replace[{
      {{"PC: ", hexFormat[regs["PC"], 2]},                                    {"RES: ", pins["RES"]}},
      {{"IR: ", commentFormat[hexFormat[regs["IR"], 1], extra["TickCount"]]}, {"SYNC: ", pins["SYNC"]}}
    },
    {a_String, b_} :> BoxForm`SummaryItem @ {a, b},
    {2}];

    sometimesVisible = Replace[{
      {{"A: ", hexFormat[regs["A"], 1]}, {"RW: ", pins["RW"]}},
      {{"X: ", hexFormat[regs["X"], 1]}, {"Data Bus: ", hexFormat[pins["DataBus"], 1]}},
      {{"Y: ", hexFormat[regs["Y"], 1]}, {"Address Bus: ", hexFormat[pins["AddressBus"], 2]}},
      {{"S: ", hexFormat[regs["S"], 1]}, {"IRQ: ", pins["IRQ"]}},
      {{"P: ", binFormat[regs["P"], 1]}, {"NMI: ", pins["NMI"]}}(*
      {{"P: ", processStatusRegFormat[regs["P"]]}}*)
    },
    {a_String, b_} :> BoxForm`SummaryItem @ {a, b},
    {2}];

    BoxForm`ArrangeSummaryBox[
      M6502,
      obj,
      BoxForm`GenericIcon["LocalTaskObject"],
      alwaysVisible,
      sometimesVisible,
      fmt,
      "Interpretable" -> True
    ]
];
