#' Render an SVG document
#'
#' Draws the document onto a surface of the requested size, cleared to
#' `background`, and returns the pixels.
#'
#' The surface size: with neither `width` nor `height`, the document's size
#' ([svg_size()]) times `scale`, rounded up; with one, the other follows the
#' document's aspect ratio; with both, the document is stretched to fill
#' them, as `rsvg::rsvg()` does.
#'
#' @inheritParams svg_size
#' @param width,height The surface size in pixels; see Details.
#' @param id Not yet supported: must be `NULL`.
#' @param scale The factor applied to the document's size when neither
#'   `width` nor `height` is given.
#' @param background The colour the surface is cleared to before drawing:
#'   anything [grDevices::col2rgb()] takes, including `"transparent"`.
#' @param color The colour CSS `currentColor` resolves to.
#' @param palette Not yet supported: must be `NULL`.
#' @param as The form of the result: only `"native"` so far, a
#'   `nativeRaster` that [grid::rasterGrob()] and [graphics::rasterImage()]
#'   draw without conversion.
#' @param max_pixels The most pixels the surface may have, at most
#'   `2^29 - 1`, or `Inf` for that.
#' @param quiet Reserved: will silence the warning for text that does not
#'   render.
#' @param ... Passed on to [svg_load()] when `x` is not already a document.
#' @return For `as = "native"`, a `nativeRaster`: an integer matrix of
#'   packed, non-premultiplied colours with `dim = c(height, width)`.
#' @export
#' @examples
#' r <- svg_render('<svg xmlns="http://www.w3.org/2000/svg" width="16"
#'   height="16"><circle cx="8" cy="8" r="7" fill="tomato"/></svg>')
#' dim(r)
#' plot.new()
#' rasterImage(r, 0, 0, 1, 1)
svg_render <- function(x, width = NULL, height = NULL, id = NULL, scale = 1,
                       background = "transparent", color = "black",
                       palette = NULL, as = "native", max_pixels = 5e7,
                       quiet = FALSE, ...) {
  call <- sys.call()
  if (!is.null(id)) zsg_invalid_argument("id", "`id` is not supported yet; it must be NULL.", call)
  if (!is.null(palette)) zsg_invalid_argument("palette", "`palette` is not supported yet; it must be NULL.", call)
  if (!identical(as, "native")) zsg_invalid_argument("as", '`as` must be "native".', call)
  zsg_arg_flag(quiet, "quiet", call)
  max_pixels <- zsg_arg_limit(max_pixels, "max_pixels", zsg_max_pixels_cap, call)
  bg <- zsg_arg_colour(background, "background", call)
  fg <- zsg_arg_colour(color, "color", call)
  doc <- zsg_as_document(x, ..., call = call)
  box <- c(0, 0, doc$width, doc$height)
  size <- zsg_render_size(box, width, height, scale, max_pixels, call)
  zsg_render_native(doc, size, box, bg, fg, call = call)
}

# The largest surface whose byte count fits plutovg's int arithmetic
# (`height * stride` in plutovg_surface_create(); design §6.1).
zsg_max_pixels_cap <- 2^29 - 1
# plutovg refuses a dimension at or above 32768.
zsg_max_dimension <- 32767

# c(width, height) in whole pixels for a render of `box` (design §5, §6.1),
# computed and checked as doubles before C sees an int.
zsg_render_size <- function(box, width, height, scale, max_pixels, call) {
  pos <- function(v, arg) {
    if (!is.null(v) && (!is.numeric(v) || length(v) != 1L || is.na(v) ||
                        !is.finite(v) || v <= 0)) {
      zsg_invalid_argument(arg, sprintf("`%s` must be NULL or a single positive number.", arg), call)
    }
    v
  }
  pos(width, "width")
  pos(height, "height")
  if (!is.numeric(scale) || length(scale) != 1L || is.na(scale) ||
      !is.finite(scale) || scale <= 0) {
    zsg_invalid_argument("scale", "`scale` must be a single positive number.", call)
  }
  bw <- box[3]
  bh <- box[4]
  if (is.null(width) && is.null(height)) {
    w <- bw * scale
    h <- bh * scale
  } else if (is.null(height)) {
    w <- width
    h <- width * bh / bw
  } else if (is.null(width)) {
    w <- height * bw / bh
    h <- height
  } else {
    w <- width
    h <- height
  }
  w <- max(1, ceiling(w))
  h <- max(1, ceiling(h))
  # GUARD: dimension
  if (!is.finite(w) || !is.finite(h) || w > zsg_max_dimension || h > zsg_max_dimension) {
    zsg_abort("zusvg_limit_error", sprintf(
      "a %s by %s surface is too large: plutovg draws at most %s pixels a side",
      zsg_num(w), zsg_num(h), zsg_num(zsg_max_dimension)),
      limit = "dimension", limit_value = zsg_max_dimension, call = call)
  }
  # GUARD: max_pixels
  if (w * h > max_pixels) {
    zsg_abort("zusvg_limit_error", sprintf(
      "a %s by %s surface has more than `max_pixels` (%s) pixels",
      zsg_num(w), zsg_num(h), zsg_num(max_pixels)),
      limit = "max_pixels", limit_value = max_pixels, call = call)
  }
  c(w, h)
}

# One R colour as c(r, g, b, a) in [0, 1] (design §6.3).
zsg_arg_colour <- function(x, arg, call) {
  rgba <- if ((is.character(x) || is.numeric(x)) && length(x) == 1L && !is.na(x)) {
    tryCatch(grDevices::col2rgb(x, alpha = TRUE), error = function(e) NULL)
  }
  if (is.null(rgba)) {
    zsg_invalid_argument(arg, sprintf("`%s` must be a single colour.", arg), call)
  }
  as.double(rgba) / 255
}

zsg_render_native <- function(doc, size, box, bg, fg, call, fail = 0L) {
  w <- size[1]
  h <- size[2]
  buf <- tryCatch(integer(w * h), error = function(e) {
    zsg_abort("zusvg_memory_error", sprintf(
      "could not allocate a %s by %s surface", zsg_num(w), zsg_num(h)), call = call)
  })
  dim(buf) <- c(as.integer(h), as.integer(w))
  status <- .Call(zusvg_render_native, doc$ptr, buf, as.double(box), bg, fg,
                  as.integer(fail))
  switch(status,
    ZSG_OK = NULL,
    ZSG_ERR_NOMEM = zsg_abort("zusvg_memory_error", sprintf(
      "could not create a %s by %s surface", zsg_num(w), zsg_num(h)), call = call),
    ZSG_ERR_RENDER = zsg_abort("zusvg_render_error",
      "plutosvg could not render the document", call = call),
    zsg_invalid_argument("x", "`x` is not a live document.", call)
  )
  class(buf) <- "nativeRaster"
  attr(buf, "channels") <- 4L
  buf
}
