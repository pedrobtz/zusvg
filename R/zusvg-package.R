#' zusvg: render SVG images without system dependencies
#'
#' zusvg renders SVG documents to pixels with bundled copies of the plutosvg
#' and plutovg C libraries, so it installs from source with no system library
#' and draws the same pixels on every platform. It is meant for icons and
#' logos. It does not render text, filters, masks, patterns, markers, CSS
#' style sheets or clip paths; a document that uses them renders without
#' them.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zusvg, .registration = TRUE
## usethis namespace: end
NULL
