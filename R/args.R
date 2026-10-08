# Argument checks shared by every entry point. A limit is a security
# property: one silently replaced by a default, or truncated from a
# fraction, is a limit the caller did not set (design §12).

zsg_describe <- function(x) {
  if (is.null(x)) return("NULL")
  sprintf("%s of length %d", paste(class(x), collapse = "/"), length(x))
}

zsg_arg_flag <- function(x, arg, call = NULL) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    zsg_invalid_argument(arg, sprintf("`%s` must be TRUE or FALSE.", arg), call)
  }
  invisible(x)
}

# A positive whole number no larger than `max`, or Inf.
zsg_arg_limit <- function(x, arg, max, call = NULL) {
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && x >= 1 &&
    (is.infinite(x) || x == trunc(x) && x <= max)
  if (!ok) {
    zsg_invalid_argument(arg, sprintf(
      "`%s` must be a whole number from 1 to %s, or Inf.", arg, zsg_num(max)), call)
  }
  invisible(as.double(x))
}

# NULL, or a single positive finite number.
zsg_arg_size <- function(x, arg, call = NULL) {
  if (is.null(x)) return(-1)
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x <= 0) {
    zsg_invalid_argument(arg, sprintf(
      "`%s` must be NULL or a single positive number.", arg), call)
  }
  as.double(x)
}

zsg_check_dots_empty <- function(dots, call = NULL) {
  if (length(dots)) {
    nm <- names(dots)
    what <- if (is.null(nm) || !nzchar(nm[1])) "an unnamed argument" else sprintf("`%s`", nm[1])
    zsg_invalid_argument("...", sprintf("unused argument: %s.", what), call)
  }
}

# The largest input plutosvg takes: it reads the length as an int.
zsg_max_size_cap <- 2^31 - 1
