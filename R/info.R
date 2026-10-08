#' Build information
#'
#' Reports the bundled plutosvg and plutovg versions, the release tags and
#' commits they were vendored from, and the local patches applied to them.
#'
#' @return A list of class `zusvg_info` with elements:
#'   * `plutosvg`, `plutovg`: each a list of `version` (the library's own
#'     version string, e.g. `"0.0.8"`), `tag` and `commit` (the upstream
#'     release the bundled copy was taken from).
#'   * `patches`: identifiers of the local patches applied to the bundled
#'     copies, in order (see `src/vendor/PROVENANCE`).
#'   * `image_formats`: the embedded image formats the bundled decoder reads.
#'   * `smoke_ok`: `TRUE` if the bundled libraries load and render a known
#'     document correctly.
#' @export
#' @examples
#' zusvg_info()
zusvg_info <- function() {
  info <- .Call(zusvg_build_info)
  patches <- if (nzchar(info$patches)) {
    strsplit(info$patches, ",", fixed = TRUE)[[1]]
  } else {
    character()
  }
  structure(
    list(
      plutosvg = list(
        version = info$plutosvg_version,
        tag = info$plutosvg_tag,
        commit = info$plutosvg_commit
      ),
      plutovg = list(
        version = info$plutovg_version,
        tag = info$plutovg_tag,
        commit = info$plutovg_commit
      ),
      patches = patches,
      image_formats = c("png", "jpeg"),
      smoke_ok = info$smoke_ok
    ),
    class = "zusvg_info"
  )
}

#' @export
format.zusvg_info <- function(x, ...) {
  lib <- function(name, l) {
    paste0(name, l$version, " (", l$tag, ", ", substr(l$commit, 1, 12), ")")
  }
  c(
    "<zusvg_info>",
    lib("plutosvg:  ", x$plutosvg),
    lib("plutovg:   ", x$plutovg),
    paste0(
      "patches:   ",
      if (length(x$patches)) paste(x$patches, collapse = ", ") else "none"
    ),
    paste0("images:    ", paste(x$image_formats, collapse = ", ")),
    paste0("self-test: ", if (isTRUE(x$smoke_ok)) "ok" else "FAILED")
  )
}

#' @export
print.zusvg_info <- function(x, ...) {
  writeLines(format(x, ...))
  invisible(x)
}
