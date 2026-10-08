#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zusvg.h"

static const R_CallMethodDef CallEntries[] = {
    {"zusvg_build_info", (DL_FUNC) &zusvg_build_info, 0},
    {NULL, NULL, 0}
};

void attribute_visible R_init_zusvg(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
