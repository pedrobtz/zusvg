#' Read an SVG file
#'
#' Reads a file, URL or connection whole and loads it as [svg_load()] does.
#' A gzip-compressed file (`.svgz`) is decompressed.
#' At most `max_size + 1` bytes are ever read, so an oversized file or an
#' endless connection fails with `zusvg_limit_error` rather than exhausting
#' memory. This is the only function that takes a path.
#'
#' A string with an `http`, `https`, `ftp`, `ftps` or `file` scheme is read
#' with [url()], any other string as a file path. A connection that is not
#' open is opened in `"rb"` mode and closed afterwards; an open one must be
#' binary, is read from its current position, and is left open.
#'
#' @param file A file path, a URL or a connection.
#' @param ... The limits and `images`, passed on to [svg_load()].
#' @inheritParams svg_load
#' @return An `svg_document`, as [svg_load()].
#' @export
#' @examples
#' path <- tempfile(fileext = ".svg")
#' writeLines('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>', path)
#' svg_read(path)
#' unlink(path)
svg_read <- function(file, width = NULL, height = NULL, ...) {
  call <- sys.call()
  dots <- list(...)
  max_size <- if (is.null(dots$max_size)) 64 * 1024^2 else dots$max_size
  max_size <- zsg_arg_limit(max_size, "max_size", zsg_max_size_cap, call)
  bytes <- zsg_read_bounded(file, max_size, "file", call)
  tryCatch(svg_load(bytes, width, height, ...), zusvg_error = function(e) {
    e$call <- call
    stop(e)
  })
}

# Reads at most max_size + 1 bytes: one past the limit is enough to know the
# input is too big, and nothing more is ever held (design §10). Adapted from
# zucbor's zu_read_bounded() (R/read.R there).
zsg_read_bounded <- function(file, max_size, what, call) {
  input <- zu_open_input(file, what = what, prefix = "zusvg",
    abort = function(arg, message) zsg_invalid_argument(arg, message, call))
  if (input$close) on.exit(close(input$con), add = TRUE)
  chunk <- 65536L
  chunks <- list()
  total <- 0
  repeat {
    want <- if (is.finite(max_size)) min(chunk, max_size + 1 - total) else chunk
    b <- tryCatch(readBin(input$con, "raw", n = want),
      error = function(e) zsg_abort("zusvg_io_error",
        paste0("could not read input: ", conditionMessage(e)), call = call))
    if (length(b) == 0L) break
    chunks[[length(chunks) + 1L]] <- b
    total <- total + length(b)
    # GUARD: max_size (reading)
    if (total > max_size) {
      zsg_raise_fault(list(status = "ZSG_ERR_SIZE", offset = max_size),
                      list(max_size = max_size), call)
    }
  }
  if (length(chunks) == 0L) raw() else unlist(chunks, use.names = FALSE)
}
