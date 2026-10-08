#ifndef ZUSVG_H
#define ZUSVG_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

SEXP zusvg_build_info(void);
SEXP zusvg_load(SEXP x, SEXP width, SEXP height, SEXP limits, SEXP images);
SEXP zusvg_status_names(void);
SEXP zusvg_doc_alive(SEXP ptr);

#endif
