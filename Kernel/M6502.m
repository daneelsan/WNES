Package["NES`"]

PackageExport["M6502"]
PackageExport["M6502Create"]
PackageExport["M6502Tick"]

(* libNES *)

importLibNESFunction[
  "M6502_getState" -> m6502$getState,
  LinkObject,
  LinkObject
];

importLibNESFunction[
  "M6502_getInstructionRegister" -> m6502$getInstructionRegister,
  {Integer},    (* Object ID           *)
  {Integer, 1}  (* {Opcode, cycle} *)
];

importLibNESFunction[
  "M6502_getRegisters" -> m6502$getRegisters,
  {Integer},    (* Object ID           *)
  {Integer, 1}  (* {PC, A, X, Y, S, P} *)
];

importLibNESFunction[
  "M6502_setRegisters" -> m6502$setRegisters,
  {
    Integer,  (* Object ID            *)
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
  "M6502_setStackPointer" ->  m6502$setStackPointer,
  {
    Integer,  (* Object ID               *)
    Integer   (* Stack Pointer new value *)
  },
  Integer     (* Stack Pointer new value *)
];

importLibNESFunction[
  "M6502_setProcessorStatus" ->  m6502$setProcessorStatus,
  {
    Integer,  (* Object ID                  *)
    Integer   (* Processor Status new value *)
  },
  Integer     (* Processor Status new value *)
];

importLibNESFunction[
  "M6502_setProgramCounter" ->  m6502$setProgramCounter,
  {
    Integer,  (* Object ID                 *)
    Integer   (* Program Counter new value *)
  },
  Integer     (* Program Counter new value *)
];

importLibNESFunction[
  "M6502_tick" -> m6502$tick,
  {
    Integer,  (* Object ID         *)
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
    (* TODO: Modify initial state *)
    obj
  ];

(* Tick *)

M6502Tick[obj_M6502 ? M6502Q, pins_Integer] := m6502$tick[getID @ obj, pins];

(* Normal *)

M6502 /: Normal[obj_M6502 ? M6502Q] := m6502$getState[getID @ obj];

(* Properties *)

HoldPattern[(obj : M6502[id_]) ? M6502Q][prop___] := m6502PropertyDispatch[obj, prop];

$m6502InstanceProperties := $m6502InstanceProperties = {
  "Properties",
  "InstanceID",
  "RegisterList",
  "RegisterAssociation",
  Splice @ $m6502Registers,
  "Opcode",
  "Cycle"
};

(** "Properties" **)

m6502PropertyDispatch[obj_, "Properties"] :=
  Sort @ $m6502InstanceProperties;

(** "InstanceID" **)

getID[obj_] := ManagedLibraryExpressionID[obj, "M6502"];

m6502PropertyDispatch[obj_, "InstanceID"] := getID @ obj;

(** "RegisterList" **)

m6502PropertyDispatch[obj_, "RegisterList"] :=
  m6502$getRegisters[getID @ obj];

(** "RegisterAssociation" **)

$m6502Registers = {"PC", "A", "X", "Y", "S", "P"};

m6502PropertyDispatch[obj_, "RegisterAssociation"] :=
  AssociationThread[$m6502Registers -> m6502PropertyDispatch[obj, "RegisterList"]];

(** "PC", "A", "X", "Y", "S", "P" **)

m6502PropertyDispatch[obj_, reg : Alternatives @@ $m6502Registers] :=
  m6502PropertyDispatch[obj, "RegisterAssociation"][reg];

(** "Opcode" **)

m6502PropertyDispatch[obj_, "Opcode"] :=
  m6502$getInstructionRegister[getID @ obj][[1]];

(** "Cycle" **)

m6502PropertyDispatch[obj_, "Cycle"] :=
  m6502$getInstructionRegister[getID @ obj][[2]];

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

(* Status update *)

SetAttributes[m6502MutationHandler, HoldAllComplete];

M6502 /: (set : Set[_M6502[_], _]) := m6502MutationHandler[set];

m6502MutationHandler[Set[(obj_M6502)[reg_], value_]] :=
  m6502UpdateState[obj, reg, value];

m6502MutationHandler[Set[sym_Symbol[reg_], value_]] :=
  m6502UpdateState[sym, reg, value];

m6502MutationHandler[other_] := (
  (* Print["Unhandled mutation: ", Hold[other]]; *)
  Language`MutationFallthrough
);

Language`SetMutationHandler[M6502, m6502MutationHandler];

$m6502ModifiableRegisters = <|
  "PC" -> m6502$setProgramCounter,
  "S"  -> m6502$setStackPointer,
  "P"  -> m6502$setProcessorStatus
|>;

KeyValueMap[
  With[{name = #1, updateF = #2},
    m6502UpdateState[obj_, name, value_] := updateF[getID @ obj, value];
  ] &,
  $m6502ModifiableRegisters
];

m6502UpdateState[_, reg_, _] :=
  Failure["M6502", <|
    "MessageTemplate" -> "The argument `arg` is not a modifiable state of the M6502 processor.",
    "MessageParameters" -> <|"arg" -> reg|>,
    "Input" -> reg
  |>];

(* SummaryBox *)

M6502 /: MakeBoxes[obj_M6502 ? M6502Q, fmt_] :=
  Module[{id, state, regs, pins, extra, alwaysVisible, sometimesVisible},
    id = getID @ obj;
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
