#include "M6502.hpp"

#include <stdint.h>

#include <unordered_map>
#define CHIPS_IMPL
#include "chips/m6502.h"

#define WS_KEYVALUE_INTEGER(mlp, key, value) \
  do {                                       \
    WSPutFunction(mlp, "Rule", 2);           \
    WSPutString(mlp, (const char*)key);      \
    WSPutInteger(mlp, value);                \
  } while (0)

#define UNITIZE(val) ((val) > 0)

std::unordered_map<mint, m6502_t*> m6502Map;

DLLEXPORT void M6502_manageInstance(WolframLibraryData libData, mbool mode, mint id) {
  if (mode == 0) {
    m6502_t* cpu = (m6502_t*)malloc(sizeof(m6502_t));
    m6502Map[id] = cpu;
    // TODO: Might want to move the initialization to its own function
    m6502_desc_t desc = {0};
    m6502_init(cpu, &desc);
  } else {
    m6502_t* cpu = m6502Map[id];
    if (cpu != NULL) free(cpu);
    m6502Map.erase(id);
  }
}

EXTERN_C DLLEXPORT int M6502_getState(WolframLibraryData libData, WSLINK mlp) {
  int argc;
  if (!WSTestHead(mlp, "List", &argc)) return LIBRARY_FUNCTION_ERROR;
  if (argc != 1) return LIBRARY_FUNCTION_ERROR;

  int id;
  if (!WSGetInteger(mlp, &id)) return LIBRARY_FUNCTION_ERROR;

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;

  if (!WSNewPacket(mlp)) return LIBRARY_FUNCTION_ERROR;

  uint16_t ir = cpu->IR;
  uint64_t pins = cpu->PINS;

  WSPutFunction(mlp, "Association", 3);

  // Pins: Start
  WSPutFunction(mlp, "Rule", 2);
  WSPutString(mlp, (const char*)"Pin");
  WSPutFunction(mlp, "Association", 8);
  WS_KEYVALUE_INTEGER(mlp, "IRQ", UNITIZE(pins & M6502_IRQ));
  WS_KEYVALUE_INTEGER(mlp, "NMI", UNITIZE(pins & M6502_NMI));
  WS_KEYVALUE_INTEGER(mlp, "RDY", UNITIZE(pins & M6502_RDY));
  WS_KEYVALUE_INTEGER(mlp, "RES", UNITIZE(pins & M6502_RES));
  WS_KEYVALUE_INTEGER(mlp, "RW", UNITIZE(pins & M6502_RW));
  WS_KEYVALUE_INTEGER(mlp, "SYNC", UNITIZE(pins & M6502_SYNC));
  WS_KEYVALUE_INTEGER(mlp, "AddressBus", pins & 0xFFFFULL);
  WS_KEYVALUE_INTEGER(mlp, "DataBus", (pins & 0xFF0000ULL) >> 16);
  // Pins: End

  // Registers: Start
  WSPutFunction(mlp, "Rule", 2);
  WSPutString(mlp, (const char*)"Register");
  WSPutFunction(mlp, "Association", 7);
  WS_KEYVALUE_INTEGER(mlp, "PC", m6502_pc(cpu));
  WS_KEYVALUE_INTEGER(mlp, "A", m6502_a(cpu));
  WS_KEYVALUE_INTEGER(mlp, "X", m6502_x(cpu));
  WS_KEYVALUE_INTEGER(mlp, "Y", m6502_y(cpu));
  WS_KEYVALUE_INTEGER(mlp, "S", m6502_s(cpu));
  WS_KEYVALUE_INTEGER(mlp, "P", m6502_p(cpu));
  WS_KEYVALUE_INTEGER(mlp, "IR", ir >> 3);
  // Registers: End

  // Extra: Start
  WSPutFunction(mlp, "Rule", 2);
  WSPutString(mlp, (const char*)"Extra");
  WSPutFunction(mlp, "Association", 1);
  WS_KEYVALUE_INTEGER(mlp, "TickCount", ir & 0b111);
  // Extra: End

  return LIBRARY_NO_ERROR;
}

// TODO: We might want to probably set/unset the pins, too
// TODO: Split setCPUState into setCPURegisters, setCPUPins, etc
EXTERN_C DLLEXPORT int M6502_setState(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res) {
  int error = LIBRARY_FUNCTION_ERROR;
  mbool success = true;

  if (Argc != 7) return error;

  mint id = MArgument_getInteger(Args[0]);
  // PC, A, X, Y, S, P
  mint pc = MArgument_getInteger(Args[1]);
  mint a = MArgument_getInteger(Args[2]);
  mint x = MArgument_getInteger(Args[3]);
  mint y = MArgument_getInteger(Args[4]);
  mint s = MArgument_getInteger(Args[5]);
  mint p = MArgument_getInteger(Args[6]);

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;

  if (pc < 0) success = false;
  if (a < 0) success = false;
  if (x < 0) success = false;
  if (y < 0) success = false;
  if (s < 0) success = false;
  if (p < 0) success = false;

  m6502_set_pc(cpu, pc);
  m6502_set_a(cpu, a);
  m6502_set_x(cpu, x);
  m6502_set_y(cpu, y);
  m6502_set_s(cpu, s);
  m6502_set_p(cpu, p);

  MArgument_setBoolean(Res, success);

  if (success) {
    error = LIBRARY_NO_ERROR;
  }
  return error;
}

EXTERN_C DLLEXPORT int M6502_set_s(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res) {
  if (Argc != 2) return LIBRARY_FUNCTION_ERROR;

  mint id = MArgument_getInteger(Args[0]);
  mint s = MArgument_getInteger(Args[1]);

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;
  if (s < 0) return LIBRARY_FUNCTION_ERROR;

  m6502_set_s(cpu, s);
  MArgument_setInteger(Res, m6502_s(cpu));

  return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int M6502_set_p(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res) {
  if (Argc != 2) return LIBRARY_FUNCTION_ERROR;

  mint id = MArgument_getInteger(Args[0]);
  mint p = MArgument_getInteger(Args[1]);

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;
  if (p < 0) return LIBRARY_FUNCTION_ERROR;

  m6502_set_p(cpu, p);
  MArgument_setInteger(Res, m6502_p(cpu));

  return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int M6502_set_pc(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res) {
  if (Argc != 2) return LIBRARY_FUNCTION_ERROR;

  mint id = MArgument_getInteger(Args[0]);
  mint pc = MArgument_getInteger(Args[1]);

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;
  if (pc < 0) return LIBRARY_FUNCTION_ERROR;

  m6502_set_pc(cpu, pc);
  MArgument_setInteger(Res, m6502_pc(cpu));

  return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int M6502_tick(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res) {
  if (Argc != 2) return LIBRARY_FUNCTION_ERROR;

  mint id = MArgument_getInteger(Args[0]);
  mint pins = MArgument_getInteger(Args[1]);

  m6502_t* cpu = m6502Map[id];
  if (cpu == NULL) return LIBRARY_FUNCTION_ERROR;
  if (pins < 0) return LIBRARY_FUNCTION_ERROR;

  pins = m6502_tick(cpu, pins);
  MArgument_setInteger(Res, pins);

  return LIBRARY_NO_ERROR;
}

EXTERN_C mint WolframLibrary_getVersion(void) { return WolframLibraryVersion; }

EXTERN_C int WolframLibrary_initialize(WolframLibraryData libData) {
  int err = LIBRARY_NO_ERROR;
  err = (*libData->registerLibraryExpressionManager)("M6502", M6502_manageInstance);
  return err;
}

EXTERN_C void WolframLibrary_uninitialize(WolframLibraryData libData) {
  (*libData->unregisterLibraryExpressionManager)("M6502");
}
