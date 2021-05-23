#ifndef __WL_UTILITIES_HPP__
#define __WL_UTILITIES_HPP__

#include "WolframHeaders/wstp.h"

#define WS_KEYVALUE_INTEGER(mlp, key, value) \
  do {                                       \
    WSPutFunction(mlp, "Rule", 2);           \
    WSPutString(mlp, (const char*)key);      \
    WSPutInteger(mlp, value);                \
  } while (0)

#define UNITIZE(val) ((val) > 0)

#endif  // __WL_UTILITIES_HPP__
