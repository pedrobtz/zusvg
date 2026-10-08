#' Size of an SVG document
#'
#' The intrinsic size plutosvg resolves for the document: the root's `width`
#' and `height` against the container size given at load, else the
#' `viewBox`, else 300 by 150.
#'
#' @param x An `svg_document` from [svg_load()] or [svg_read()], or anything
#'   [svg_load()] accepts.
#' @param ... Passed on to [svg_load()] when `x` is not already a document.
#' @return A named double vector, `c(width = , height = )`, in CSS pixels.
#' @export
#' @examples
#' svg_size('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 24"/>')
svg_size <- function(x, ...) {
  doc <- zsg_as_document(x, ..., call = sys.call())
  c(width = doc$width, height = doc$height)
}
