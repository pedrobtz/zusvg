#' Check that a document loads
#'
#' Loads `x` under the same limits as [svg_load()] and reports the outcome
#' instead of raising it, for gating a batch of untrusted files.
#'
#' @inheritParams svg_size
#' @return `TRUE` if the document loads; otherwise the classed condition
#'   [svg_load()] would have raised (see [zusvg-conditions]), returned rather
#'   than signalled. An unusable argument is still an error.
#' @export
#' @examples
#' svg_validate('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>')
#' svg_validate("<svg><g></svg>")
svg_validate <- function(x, ...) {
  call <- sys.call()
  tryCatch({
    zsg_as_document(x, ..., call = call)
    TRUE
  }, zusvg_error = function(e) {
    if (inherits(e, "zusvg_invalid_argument")) stop(e)
    e
  })
}
