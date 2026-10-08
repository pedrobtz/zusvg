#' Render an SVG document
#'
#' Draws the document onto a surface of the requested size, cleared to
#' `background`, and returns the pixels.
#'
#' The surface size: with neither `width` nor `height`, the document's size
#' ([svg_size()]) times `scale`, rounded up; with one, the other follows the
#' document's aspect ratio; with both, the document is stretched to fill
#' them, as the rsvg package's `rsvg()` does.
#'
#' @inheritParams svg_size
#' @param width,height The surface size in pixels; see Details.
#' @param id The `id` of one element to render alone, cropped to its
#'   extents ([svg_extents()]); `NULL` renders the whole document.
#' @param scale The factor applied to the document's size when neither
#'   `width` nor `height` is given.
#' @param background The colour the surface is cleared to before drawing:
#'   anything [grDevices::col2rgb()] takes, including `"transparent"`.
#' @param color The colour CSS `currentColor` resolves to.
#' @param palette A named character vector of colours answering CSS
#'   `var(--name)` by `name` (without the `--`), e.g.
#'   `c(primary = "#1e88e5")`. A name not present leaves the variable to its
#'   fallback, as plutosvg does.
#' @param as The form of the result:
#'   * `"native"`, a `nativeRaster` that [grid::rasterGrob()] and
#'     [graphics::rasterImage()] draw without conversion;
#'   * `"array"`, a `height x width x 4` double array in `[0, 1]`, the shape
#'     rsvg's `rsvg()` returns, which [as.raster()] and [png::writePNG()]
#'     take;
#'   * `"raw"`, RGBA bytes with `dim = c(4, width, height)`, the shape
#'     rsvg's `rsvg_raw()` returns and magick's `image_read()` takes.
#' @param max_pixels The most pixels the surface may have, at most
#'   `2^29 - 1`, or `Inf` for that.
#' @param quiet If `TRUE`, no warning is given for content that will not
#'   render. Otherwise each call warns once for text
#'   (`zusvg_text_skipped`) and once for clip paths that would change the
#'   picture (`zusvg_clip_skipped`), each with the `count` affected; both
#'   inherit `zusvg_warning`.
#' @param ... Passed on to [svg_load()] when `x` is not already a document.
#' @return The pixels, non-premultiplied, in the form `as` names. For
#'   `as = "native"`, an integer matrix of class `nativeRaster` with
#'   `dim = c(height, width)`.
#' @export
#' @examples
#' r <- svg_render('<svg xmlns="http://www.w3.org/2000/svg" width="16"
#'   height="16"><circle cx="8" cy="8" r="7" fill="tomato"/></svg>')
#' dim(r)
#' plot.new()
#' rasterImage(r, 0, 0, 1, 1)
svg_render <- function(x, width = NULL, height = NULL, id = NULL, scale = 1,
                       background = "transparent", color = "black",
                       palette = NULL, as = c("native", "array", "raw"),
                       max_pixels = 5e7, quiet = FALSE, ...) {
  call <- sys.call()
  as <- zsg_arg_choice(as, c("native", "array", "raw"), "as", call)
  job <- zsg_prepare(x, width, height, id, scale, background, color, palette,
                     max_pixels, quiet, ..., call = call)
  r <- zsg_render_native(job$doc, job$size, job$box, job$bg, job$fg,
                         id = job$id, pal = job$pal, call = call)
  switch(as,
    native = r,
    array = .Call(zusvg_native_to_array, r),
    raw = .Call(zusvg_native_to_raw, r)
  )
}

# Everything a render needs, checked, with the warnings for what will not
# render signalled once (design §6.4, D11, D15).
zsg_prepare <- function(x, width, height, id, scale, background, color,
                        palette, max_pixels, quiet, ..., call) {
  zsg_arg_id(id, call)
  pal <- zsg_arg_palette(palette, call)
  zsg_arg_flag(quiet, "quiet", call)
  max_pixels <- zsg_arg_limit(max_pixels, "max_pixels", zsg_max_pixels_cap, call)
  bg <- zsg_arg_colour(background, "background", call)
  fg <- zsg_arg_colour(color, "color", call)
  doc <- zsg_as_document(x, ..., call = call)
  box <- if (is.null(id)) c(0, 0, doc$width, doc$height) else zsg_extents(doc, id, call)
  if (!(box[3] > 0 && box[4] > 0)) {
    zsg_abort("zusvg_render_error", sprintf(
      "element \"%s\" draws nothing, so it has no size to render at", id), call = call)
  }
  size <- zsg_render_size(box, width, height, scale, max_pixels, call)
  if (!quiet) zsg_warn_unrendered(doc, id, call)
  list(doc = doc, size = size, box = box, bg = bg, fg = fg, id = id, pal = pal)
}

zsg_warn <- function(class, message, ..., call = NULL) {
  warning(structure(
    class = c(class, "zusvg_warning", "warning", "condition"),
    list(message = message, call = call, ...)
  ))
}

# One warning per kind of content that will not render, for the part being
# rendered: the whole document, or the subtree of `id`.
zsg_warn_unrendered <- function(doc, id, call) {
  e <- doc$elements
  if (is.null(id)) {
    n_text <- doc$n_text
    n_clip <- as.double(sum(e$clip))
  } else {
    i <- zsg_element_index(doc, id)
    n_text <- e$n_text[i]
    inside <- zsg_in_subtree(e$parent, i)
    n_clip <- as.double(sum(e$clip[inside]))
  }
  if (n_text > 0) {
    zsg_warn("zusvg_text_skipped", sprintf(
      "%s text element%s will not render: zusvg does not draw text",
      zsg_num(n_text), if (n_text == 1) "" else "s"), count = n_text, call = call)
  }
  if (n_clip > 0) {
    zsg_warn("zusvg_clip_skipped", sprintf(
      "%s clip path%s will not be applied: plutosvg does not clip",
      zsg_num(n_clip), if (n_clip == 1) "" else "s"), count = n_clip, call = call)
  }
}

# Which elements are in the subtree rooted at element i (itself included).
zsg_in_subtree <- function(parent, i) {
  inside <- logical(length(parent))
  inside[i] <- TRUE
  for (k in seq_along(parent)) {
    p <- parent[k]
    if (!is.na(p) && inside[p]) inside[k] <- TRUE
  }
  inside
}

#' Extents of a document or element
#'
#' The bounding box of what the document, or one element, draws, in the
#' document's user units, as plutosvg computes it. This is what
#' [svg_render()] crops to when given `id`, and how an icon sheet is cut into
#' icons.
#'
#' @inheritParams svg_size
#' @param id The `id` of an element, or `NULL` for the whole document.
#' @return A named double vector `c(x = , y = , width = , height = )`. An
#'   element that draws nothing has zero width and height.
#' @export
#' @examples
#' sheet <- '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">
#'   <circle id="a" cx="10" cy="10" r="8"/><rect id="b" x="24" y="4"
#'   width="12" height="12"/></svg>'
#' svg_extents(sheet)
#' svg_extents(sheet, id = "b")
svg_extents <- function(x, id = NULL, ...) {
  call <- sys.call()
  zsg_arg_id(id, call)
  doc <- zsg_as_document(x, ..., call = call)
  e <- zsg_extents(doc, id, call)
  c(x = e[1], y = e[2], width = e[3], height = e[4])
}

zsg_extents <- function(doc, id, call) {
  e <- .Call(zusvg_extents, doc$ptr, id)
  if (is.null(e)) {
    zsg_abort("zusvg_missing_element", sprintf("no element has id \"%s\"", id),
              id = id, call = call)
  }
  if (is.character(e)) zsg_invalid_argument("x", "`x` is not a live document.", call)
  e
}

zsg_arg_id <- function(id, call) {
  if (!is.null(id) && (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id))) {
    zsg_invalid_argument("id", "`id` must be NULL or a single non-empty string.", call)
  }
  invisible(id)
}

zsg_arg_choice <- function(x, choices, arg, call) {
  if (identical(x, choices)) return(choices[1])
  if (!is.character(x) || length(x) != 1L || !(x %in% choices)) {
    zsg_invalid_argument(arg, sprintf("`%s` must be one of %s.", arg,
      paste0('"', choices, '"', collapse = ", ")), call)
  }
  x
}

# A palette as list(names, colours): names without "--", colours as a
# 4 x n matrix in [0, 1] (design §6.3, D8).
zsg_arg_palette <- function(palette, call) {
  if (is.null(palette)) return(list(names = character(), colors = double()))
  nm <- names(palette)
  if (!is.character(palette) || is.null(nm) || anyNA(nm) || any(!nzchar(nm)) ||
      anyNA(palette) || anyDuplicated(sub("^--", "", nm))) {
    zsg_invalid_argument("palette", paste0(
      "`palette` must be a character vector of colours with unique, ",
      "non-empty names."), call)
  }
  cols <- vapply(seq_along(palette), function(i) {
    zsg_arg_colour(palette[[i]], sprintf("palette[[\"%s\"]]", nm[i]), call)
  }, double(4))
  list(names = enc2utf8(sub("^--", "", nm)), colors = as.double(cols))
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

zsg_render_native <- function(doc, size, box, bg, fg, call, id = NULL,
                              pal = list(names = character(), colors = double()),
                              fail = 0L) {
  w <- size[1]
  h <- size[2]
  buf <- tryCatch(integer(w * h), error = function(e) {
    zsg_abort("zusvg_memory_error", sprintf(
      "could not allocate a %s by %s surface", zsg_num(w), zsg_num(h)), call = call)
  })
  dim(buf) <- c(as.integer(h), as.integer(w))
  status <- .Call(zusvg_render_native, doc$ptr, buf, as.double(box), bg, fg,
                  if (is.null(id)) NULL else enc2utf8(id), pal$names, pal$colors,
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
