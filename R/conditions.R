# The condition hierarchy of design §11. The class is the contract: callers
# branch on it and on the fields below, never on the message.

#' Conditions raised by zusvg
#'
#' Every error zusvg raises carries a condition class, so it can be caught
#' by kind rather than by matching the message, which may change. Every
#' class below inherits from `zusvg_error`.
#'
#' \describe{
#'   \item{`zusvg_invalid_argument`}{An argument was unusable: an input of
#'     the wrong type, a limit that is not a positive whole number, a bad
#'     colour. Carries `arg`, the argument at fault.}
#'   \item{`zusvg_parse_error`}{The document is not one plutosvg can load:
#'     it is malformed, its root is not `<svg>`, or its size is not
#'     positive.}
#'   \item{`zusvg_encoding_error`}{The input is not UTF-8, or holds a NUL
#'     byte.}
#'   \item{`zusvg_limit_error`}{A limit was reached. Carries `limit`, the
#'     argument's name, such as `"max_size"`, and `limit_value`.}
#'   \item{`zusvg_missing_element`}{An `id` is not in the document.}
#'   \item{`zusvg_render_error`}{plutosvg could not render the document.}
#'   \item{`zusvg_memory_error`}{An allocation failed.}
#'   \item{`zusvg_io_error`}{A file or connection could not be read or
#'     written.}
#' }
#'
#' A `zusvg_parse_error`, `zusvg_encoding_error` or `zusvg_limit_error`
#' raised while loading carries `offset`, the 0-based byte offset of the
#' fault in the input, or `NA` when no position is known: plutosvg's loader
#' reports none, nor does the UTF-8 check.
#'
#' @name zusvg-conditions
#' @examples
#' tryCatch(
#'   svg_load("<svg><rect></svg>"),
#'   zusvg_parse_error = function(e) e$offset
#' )
NULL

zsg_abort <- function(class, message, ..., call = NULL) {
  stop(structure(
    class = c(class, "zusvg_error", "error", "condition"),
    list(message = message, call = call, ...)
  ))
}

zsg_invalid_argument <- function(arg, message, call = NULL) {
  zsg_abort("zusvg_invalid_argument", message, arg = arg, call = call)
}

# Status name (src/zsg_scan.h) -> how R reports it. test-conditions.R checks
# that every status C can report is here.
zsg_status_class <- c(
  ZSG_ERR_ENCODING = "zusvg_encoding_error",
  ZSG_ERR_SYNTAX = "zusvg_parse_error",
  ZSG_ERR_SIZE = "zusvg_limit_error",
  ZSG_ERR_ELEMENTS = "zusvg_limit_error",
  ZSG_ERR_DEPTH = "zusvg_limit_error",
  ZSG_ERR_IMAGE = "zusvg_limit_error",
  ZSG_ERR_NOMEM = "zusvg_memory_error",
  ZSG_ERR_LOAD = "zusvg_parse_error"
)

zsg_status_limit <- c(
  ZSG_ERR_SIZE = "max_size",
  ZSG_ERR_ELEMENTS = "max_elements",
  ZSG_ERR_DEPTH = "max_depth",
  ZSG_ERR_IMAGE = "images"
)

# Raises the condition for a fault list(status, offset) from C. `limits` is
# the named list of limit values in force.
zsg_raise_fault <- function(res, limits, call = NULL) {
  status <- res$status
  class <- zsg_status_class[[status]]
  offset <- res$offset
  at <- if (is.na(offset)) "" else sprintf(" at byte %s", format(offset, scientific = FALSE))
  if (class == "zusvg_limit_error") {
    limit <- zsg_status_limit[[status]]
    value <- limits[[limit]]
    message <- switch(status,
      ZSG_ERR_SIZE = sprintf("input is larger than `max_size` (%s bytes)", zsg_num(value)),
      ZSG_ERR_ELEMENTS = sprintf("document has more than `max_elements` (%s) elements%s", zsg_num(value), at),
      ZSG_ERR_DEPTH = sprintf("document nests deeper than `max_depth` (%s)%s", zsg_num(value), at),
      ZSG_ERR_IMAGE = sprintf("document has an <image> element%s and `images = FALSE`", at)
    )
    zsg_abort(class, message, offset = offset, limit = limit,
              limit_value = value, call = call)
  }
  message <- switch(status,
    ZSG_ERR_ENCODING = sprintf("input is not UTF-8 text%s", at),
    ZSG_ERR_SYNTAX = sprintf("not an SVG document plutosvg can load: malformed%s", at),
    ZSG_ERR_LOAD = "not an SVG document plutosvg can load: no positive size, or refused by the loader",
    ZSG_ERR_NOMEM = "out of memory while loading the document"
  )
  zsg_abort(class, message, offset = offset, call = call)
}

zsg_num <- function(x) format(x, scientific = FALSE, big.mark = "")
