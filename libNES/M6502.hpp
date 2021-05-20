// Library definition for Wolfram LibraryLink

#ifndef __M6502_HPP__
#define __M6502_HPP__

#include "WolframHeaders/WolframLibrary.h"
#include "WolframHeaders/wstp.h"

/** @brief Returns the state of an M6502 instance as an association.
 */
EXTERN_C DLLEXPORT int M6502_getState(WolframLibraryData libData, WSLINK mlp);

/** @brief Modifies the state of an M6502 instance.
 */
EXTERN_C DLLEXPORT int M6502_setState(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res);

/** @brief Sets the stack pointer register S.
 */
EXTERN_C DLLEXPORT int M6502_set_s(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res);

/** @brief Sets the processor status register P.
 */
EXTERN_C DLLEXPORT int M6502_set_p(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res);

/** @brief Sets the program counter PC.
 */
EXTERN_C DLLEXPORT int M6502_set_pc(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res);

/** @brief Executes one tick of an M6502 instance.
 */
EXTERN_C DLLEXPORT int M6502_tick(WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res);

EXTERN_C DLLEXPORT mint WolframLibrary_getVersion(void);

EXTERN_C DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData);

EXTERN_C DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData);

#endif  // __M6502_HPP__
