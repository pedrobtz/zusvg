#ifndef ZUSVG_H
#define ZUSVG_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

SEXP zusvg_build_info(void);
SEXP zusvg_load(SEXP x, SEXP width, SEXP height, SEXP limits, SEXP images);
SEXP zusvg_status_names(void);
SEXP zusvg_doc_alive(SEXP ptr);
SEXP zusvg_render_native(SEXP ptr, SEXP buf, SEXP box, SEXP background,
                         SEXP color, SEXP id, SEXP pal_names, SEXP pal_colors,
                         SEXP fail);
SEXP zusvg_render_encode(SEXP ptr, SEXP buf, SEXP box, SEXP background,
                         SEXP color, SEXP id, SEXP pal_names, SEXP pal_colors,
                         SEXP fail, SEXP format, SEXP quality);
SEXP zusvg_extents(SEXP ptr, SEXP id);
SEXP zusvg_native_to_array(SEXP buf);
SEXP zusvg_native_to_raw(SEXP buf);

#endif
