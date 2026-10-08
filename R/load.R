#' Load an SVG document
#'
#' Checks the input under the limits, then parses it with plutosvg into a
#' document that the rendering and measuring functions take. Every one of
#' them also accepts what `svg_load()` accepts, loading it on the way, so
#' calling `svg_load()` first is only needed to load once and render many
#' times, or to set the container size.
#'
#' A character `x` is always the document's text, never a file path: read a
#' file with [svg_read()].
#'
#' @param x The document: a raw vector of its bytes, a single string holding
#'   its text, or a connection to read it from. gzip-compressed bytes (an
#'   `.svgz` file's) are decompressed, with `max_size` bounding the
#'   decompressed size.
#' @param width,height The container size in CSS pixels that a root
#'   `width="100%"` resolves against. `NULL`, the default, falls back to the
#'   `viewBox`, then to 300 by 150, as plutosvg does.
#' @param ... Must be empty; it forces the limits to be named.
#' @param max_size The most bytes read from any source, and the most a
#'   compressed input may decompress to; at most `2^31 - 1`, or `Inf` for
#'   that.
#' @param max_elements The most start tags the document may have.
#' @param max_depth The deepest the document's elements may nest.
#' @param images If `FALSE`, a document with an `<image>` element is refused
#'   before anything decodes it: use it for untrusted input.
#' @return An `svg_document`: an object holding the loaded document.
#'   `print()` shows its size and element count, and `dim()` gives
#'   `c(height, width)` rounded up, as [svg_size()] reports them.
#' @seealso [zusvg-conditions] for the errors it raises.
#' @export
#' @examples
#' doc <- svg_load('<svg xmlns="http://www.w3.org/2000/svg" width="24"
#'   height="24"><circle cx="12" cy="12" r="10"/></svg>')
#' doc
#' dim(doc)
svg_load <- function(x, width = NULL, height = NULL, ...,
                     max_size = 64 * 1024^2, max_elements = 1e5,
                     max_depth = 256, images = TRUE) {
  call <- sys.call()
  zsg_check_dots_empty(list(...), call)
  if (inherits(x, "svg_document")) {
    zsg_invalid_argument("x", "`x` is already a loaded document.", call)
  }
  width <- zsg_arg_size(width, "width", call)
  height <- zsg_arg_size(height, "height", call)
  limits <- list(
    max_size = zsg_arg_limit(max_size, "max_size", zsg_max_size_cap, call),
    max_elements = zsg_arg_limit(max_elements, "max_elements", 2^53, call),
    max_depth = zsg_arg_limit(max_depth, "max_depth", 2^31 - 1, call),
    images = zsg_arg_flag(images, "images", call)
  )
  bytes <- zsg_input_bytes(x, limits$max_size, call)
  zsg_load_bytes(bytes, width, height, limits, call)
}

zsg_input_bytes <- function(x, max_size, call) {
  if (is.raw(x)) {
    bytes <- x
  } else if (is.character(x) && length(x) == 1L && !is.na(x)) {
    bytes <- charToRaw(enc2utf8(x))
  } else if (inherits(x, "connection")) {
    bytes <- zsg_read_bounded(x, max_size, "x", call)
  } else {
    zsg_invalid_argument("x", sprintf(
      "`x` must be a raw vector, a single string or a connection, not %s.",
      zsg_describe(x)), call)
  }
  # GUARD: max_size (before the copy into C; the pre-scan checks again)
  if (length(bytes) > max_size) {
    zsg_raise_fault(list(status = "ZSG_ERR_SIZE", offset = max_size),
                    list(max_size = max_size), call)
  }
  # gzip (.svgz): decompressed by base R's gzfile() under the same bounded
  # read, so max_size caps the decompressed size and a small compression
  # bomb fails as a limit error (design §10). Through a temporary file, not
  # gzcon(rawConnection()), whose setup reads uninitialised memory in R
  # itself (valgrind, R 4.6).
  if (length(bytes) >= 2L && bytes[1] == as.raw(0x1f) && bytes[2] == as.raw(0x8b)) {
    path <- tempfile(fileext = ".svgz")
    on.exit(unlink(path), add = TRUE)
    writeBin(bytes, path)
    bytes <- withCallingHandlers(
      zsg_read_bounded(gzfile(path), max_size, "x", call),
      warning = function(w) {
        zsg_abort("zusvg_parse_error", paste0("input is not valid gzip: ", conditionMessage(w)),
                  offset = NA_real_, call = call)
      }
    )
  }
  bytes
}

zsg_load_bytes <- function(bytes, width, height, limits, call) {
  res <- .Call(zusvg_load, bytes, width, height,
               c(limits$max_size, limits$max_elements, limits$max_depth),
               limits$images)
  if (res$status != "ZSG_OK") zsg_raise_fault(res, limits, call)
  elements <- data.frame(
    id = res$ids, tag = res$tags, parent = res$parent, n_text = res$n_text_in,
    stringsAsFactors = FALSE
  )
  attrs <- data.frame(
    elem = res$attr_elem, name = res$attr_name, value = res$attr_value,
    stringsAsFactors = FALSE
  )
  doc <- structure(
    list(
      ptr = res$ptr,
      width = res$width,
      height = res$height,
      n_elements = as.double(nrow(elements)),
      n_text = res$n_text,
      n_image = res$n_image,
      elements = elements,
      attrs = attrs
    ),
    class = "svg_document"
  )
  doc$elements$clip <- zsg_clip_effective(doc)
  doc
}

# x as a live document: a loaded one as is, anything else through
# svg_load() with `...`.
zsg_as_document <- function(x, ..., call = NULL) {
  if (inherits(x, "svg_document")) {
    zsg_check_dots_empty(list(...), call)
    if (!.Call(zusvg_doc_alive, x$ptr)) {
      zsg_invalid_argument("x", paste0(
        "`x` is a document from another R session (saved and restored); ",
        "load it again."), call)
    }
    return(x)
  }
  doc <- tryCatch(svg_load(x, ...), zusvg_error = function(e) {
    e$call <- call
    stop(e)
  })
  doc
}

#' @export
format.svg_document <- function(x, ...) {
  n <- x$n_elements
  text <- if (x$n_text > 0) {
    sprintf(" (%s text element%s will not render)", zsg_num(x$n_text),
            if (x$n_text == 1) "" else "s")
  } else {
    ""
  }
  sprintf("<svg_document> %s x %s, %s element%s%s",
          format(x$width), format(x$height), zsg_num(n),
          if (n == 1) "" else "s", text)
}

#' @export
print.svg_document <- function(x, ...) {
  writeLines(format(x, ...))
  invisible(x)
}

#' @export
dim.svg_document <- function(x) {
  c(ceiling(x$height), ceiling(x$width))
}
