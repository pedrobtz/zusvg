#' Render an SVG document to PNG or JPEG
#'
#' Renders as [svg_render()] does and encodes the pixels with the bundled
#' `stb_image_write`. The output is the same bytes on every platform for the
#' same document and arguments.
#'
#' JPEG has no transparency, so `svg_jpeg()` clears the surface to white
#' unless told otherwise.
#'
#' @inheritParams svg_render
#' @param file `NULL` to return the encoded bytes, or a file path or a
#'   binary connection to write them to.
#' @param ... Arguments passed on to [svg_render()] (all but `as`), and from
#'   there to [svg_load()].
#' @param quality JPEG quality, a whole number from 1 to 100.
#' @return With `file = NULL`, a raw vector of the encoded image; otherwise
#'   `file`, invisibly.
#' @export
#' @examples
#' icon <- '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
#'   <circle cx="8" cy="8" r="7" fill="tomato"/></svg>'
#' png <- svg_png(icon, width = 64)
#' png[1:8]
#' path <- tempfile(fileext = ".jpg")
#' svg_jpeg(icon, path, quality = 80)
#' unlink(path)
svg_png <- function(x, file = NULL, ...) {
  call <- sys.call()
  zsg_encode(x, file, format = 0L, quality = 0L, call = call, ...)
}

#' @rdname svg_png
#' @export
svg_jpeg <- function(x, file = NULL, quality = 90, background = "white", ...) {
  call <- sys.call()
  if (!is.numeric(quality) || length(quality) != 1L || is.na(quality) ||
      quality < 1 || quality > 100 || quality != trunc(quality)) {
    zsg_invalid_argument("quality", "`quality` must be a whole number from 1 to 100.", call)
  }
  zsg_encode(x, file, format = 1L, quality = as.integer(quality), call = call,
             background = background, ...)
}

zsg_encode <- function(x, file, format, quality, call, width = NULL, height = NULL,
                       id = NULL, scale = 1, background = "transparent",
                       color = "black", palette = NULL, max_pixels = 5e7,
                       quiet = FALSE, ..., fail = 0L) {
  if (!is.null(file) && !inherits(file, "connection") &&
      !(is.character(file) && length(file) == 1L && !is.na(file))) {
    zsg_invalid_argument("file", "`file` must be NULL, a file path or a connection.", call)
  }
  job <- zsg_prepare(x, width, height, id, scale, background, color, palette,
                     max_pixels, quiet, ..., call = call)
  w <- job$size[1]
  h <- job$size[2]
  buf <- tryCatch(integer(w * h), error = function(e) {
    zsg_abort("zusvg_memory_error", sprintf(
      "could not allocate a %s by %s surface", zsg_num(w), zsg_num(h)), call = call)
  })
  dim(buf) <- c(as.integer(h), as.integer(w))
  out <- .Call(zusvg_render_encode, job$doc$ptr, buf, as.double(job$box), job$bg,
               job$fg, if (is.null(job$id)) NULL else enc2utf8(job$id),
               job$pal$names, job$pal$colors, as.integer(fail), format, quality)
  if (is.character(out)) {
    switch(out,
      ZSG_ERR_NOMEM = zsg_abort("zusvg_memory_error",
        "out of memory while rendering or encoding the image", call = call),
      ZSG_ERR_RENDER = zsg_steps_error(call),
      ZSG_ERR_ENCODE = zsg_abort("zusvg_render_error",
        "the image could not be encoded", call = call),
      zsg_invalid_argument("x", "`x` is not a live document.", call)
    )
  }
  if (is.null(file)) return(out)
  tryCatch(writeBin(out, file), error = function(e) {
    zsg_abort("zusvg_io_error", paste0("could not write the image: ", conditionMessage(e)),
              call = call)
  })
  invisible(file)
}
