#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zusvg.h"

static const R_CallMethodDef CallEntries[] = {
    {"zusvg_build_info",   (DL_FUNC) &zusvg_build_info,   0},
    {"zusvg_load",         (DL_FUNC) &zusvg_load,         5},
    {"zusvg_status_names", (DL_FUNC) &zusvg_status_names, 0},
    {"zusvg_doc_alive",    (DL_FUNC) &zusvg_doc_alive,    1},
    {"zusvg_render_native", (DL_FUNC) &zusvg_render_native, 6},
    {NULL, NULL, 0}
};

void attribute_visible R_init_zusvg(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
