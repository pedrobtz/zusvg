#' Elements of an SVG document
#'
#' Lists the elements that have an `id`, among those plutosvg draws, with
#' what will not render inside each. It is the tool for cutting an icon
#' sheet into icons with [svg_render()]'s `id`, and for deciding whether
#' zusvg can draw a file.
#'
#' @inheritParams svg_size
#' @return A data frame, one row per element with an `id`, in document
#'   order:
#'   * `id`: the element's `id`.
#'   * `tag`: its element name, such as `"g"`, `"symbol"` or `"path"`.
#'   * `has_text`: whether it contains text, which does not render.
#'   * `has_clip`: whether it, or something inside it, uses a clip path
#'     that would change the picture. Clip paths are not applied (see
#'     [svg_render()]).
#'
#'   When two elements share an `id`, plutosvg finds the last one.
#' @export
#' @examples
#' svg_elements('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">
#'   <g id="a"><circle cx="10" cy="10" r="8"/></g>
#'   <g id="b"><text x="24" y="14">B</text></g></svg>')
svg_elements <- function(x, ...) {
  doc <- zsg_as_document(x, ..., call = sys.call())
  e <- doc$elements
  keep <- !is.na(e$id)
  data.frame(
    id = e$id[keep],
    tag = e$tag[keep],
    has_text = e$n_text[keep] > 0,
    has_clip = zsg_subtree_any(e$clip, e$parent)[keep],
    stringsAsFactors = FALSE
  )
}

# For each element, whether some element in its subtree (itself included)
# has flag TRUE. Elements are in document order, so a child always follows
# its parent: one reverse pass carries flags up.
zsg_subtree_any <- function(flag, parent) {
  out <- flag
  for (i in rev(seq_along(parent))) {
    p <- parent[i]
    if (!is.na(p) && out[i]) out[p] <- TRUE
  }
  out
}

# The 1-based index of the element plutosvg finds for an id (the last one
# to give it), or NA.
zsg_element_index <- function(doc, id) {
  i <- which(doc$elements$id == id)
  if (length(i)) i[length(i)] else NA_integer_
}

# For each element: does it reference a clip path that would change the
# picture? A clip is a no-op, and not reported (design D15), when the
# <clipPath> holds one untransformed <rect> covering the whole canvas; a
# reference to an id that is not a <clipPath> clips nothing in any
# renderer. The canvas is the root's viewBox, or its size without one.
zsg_clip_effective <- function(doc) {
  e <- doc$elements
  a <- doc$attrs
  n <- nrow(e)
  out <- logical(n)
  if (n == 0L) return(out)
  val <- function(i, name) {
    v <- a$value[a$elem == i & a$name == name]
    if (length(v)) v[length(v)] else NA_character_
  }
  # The clip-path references: the attribute, or a style declaration.
  refs <- rep(NA_character_, n)
  cp <- a[a$name == "clip-path", ]
  refs[cp$elem] <- cp$value
  st <- a[a$name == "style" & grepl("clip-path", a$value, fixed = TRUE), ]
  refs[st$elem] <- sub(".*clip-path\\s*:\\s*([^;]*).*", "\\1", st$value)
  target <- sub("^\\s*url\\(\\s*['\"]?#([^)'\"]+)['\"]?\\s*\\)\\s*$", "\\1", refs)
  target[!grepl("^\\s*url\\(", refs)] <- NA_character_

  root <- which(is.na(e$parent))[1]
  vb <- as.numeric(strsplit(trimws(val(root, "viewBox")), "[[:space:],]+")[[1]])
  canvas <- if (length(vb) == 4L && !anyNA(vb)) vb else c(0, 0, doc$width, doc$height)

  num <- function(v) {
    if (is.na(v)) return(NA_real_)
    v <- trimws(v)
    if (v == "100%") return(Inf)
    suppressWarnings(as.numeric(sub("px$", "", v)))
  }
  noop <- function(clip) {
    if (is.na(clip) || e$tag[clip] != "clipPath") return(TRUE)
    kids <- which(e$parent == clip)
    if (length(kids) != 1L || e$tag[kids] != "rect") return(FALSE)
    if (!is.na(val(clip, "transform")) || !is.na(val(kids, "transform"))) return(FALSE)
    x <- if (is.na(val(kids, "x"))) 0 else num(val(kids, "x"))
    y <- if (is.na(val(kids, "y"))) 0 else num(val(kids, "y"))
    w <- num(val(kids, "width"))
    h <- num(val(kids, "height"))
    if (anyNA(c(x, y, w, h))) return(FALSE)
    if (identical(trimws(val(clip, "clipPathUnits")), "objectBoundingBox")) {
      return(x <= 0 && y <= 0 && x + w >= 1 && y + h >= 1)
    }
    x <= canvas[1] && y <= canvas[2] && x + w >= canvas[1] + canvas[3] &&
      y + h >= canvas[2] + canvas[4]
  }
  for (i in which(!is.na(target))) {
    out[i] <- !noop(zsg_element_index(doc, target[i]))
  }
  out
}
