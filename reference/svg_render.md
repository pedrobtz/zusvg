# Render an SVG document

Draws the document onto a surface of the requested size, cleared to
`background`, and returns the pixels.

## Usage

``` r
svg_render(
  x,
  width = NULL,
  height = NULL,
  id = NULL,
  scale = 1,
  background = "transparent",
  color = "black",
  palette = NULL,
  as = c("native", "array", "raw"),
  max_pixels = 5e+07,
  quiet = FALSE,
  ...
)
```

## Arguments

- x:

  An `svg_document` from
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  or
  [`svg_read()`](https://pedrobtz.github.io/zusvg/reference/svg_read.md),
  or anything
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  accepts.

- width, height:

  The surface size in pixels; see Details.

- id:

  The `id` of one element to render alone, cropped to its extents
  ([`svg_extents()`](https://pedrobtz.github.io/zusvg/reference/svg_extents.md));
  `NULL` renders the whole document.

- scale:

  The factor applied to the document's size when neither `width` nor
  `height` is given.

- background:

  The colour the surface is cleared to before drawing: anything
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  takes, including `"transparent"`.

- color:

  The colour CSS `currentColor` resolves to.

- palette:

  A named character vector of colours answering CSS `var(--name)` by
  `name` (without the `--`), e.g. `c(primary = "#1e88e5")`. A name not
  present leaves the variable to its fallback, as plutosvg does.

- as:

  The form of the result:

  - `"native"`, a `nativeRaster` that
    [`grid::rasterGrob()`](https://rdrr.io/r/grid/grid.raster.html) and
    [`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html)
    draw without conversion;

  - `"array"`, a `height x width x 4` double array in `[0, 1]`, the
    shape rsvg's `rsvg()` returns, which
    [`as.raster()`](https://rdrr.io/r/grDevices/as.raster.html) and
    [`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html) take;

  - `"raw"`, RGBA bytes with `dim = c(4, width, height)`, the shape
    rsvg's `rsvg_raw()` returns and magick's `image_read()` takes.

- max_pixels:

  The most pixels the surface may have, at most `2^29 - 1`, or `Inf` for
  that.

- quiet:

  If `TRUE`, no warning is given for content that will not render.
  Otherwise each call warns once for text (`zusvg_text_skipped`) and
  once for clip paths that would change the picture
  (`zusvg_clip_skipped`), each with the `count` affected; both inherit
  `zusvg_warning`.

- ...:

  Passed on to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  when `x` is not already a document.

## Value

The pixels, non-premultiplied, in the form `as` names. For
`as = "native"`, an integer matrix of class `nativeRaster` with
`dim = c(height, width)`.

## Details

The surface size: with neither `width` nor `height`, the document's size
([`svg_size()`](https://pedrobtz.github.io/zusvg/reference/svg_size.md))
times `scale`, rounded up; with one, the other follows the document's
aspect ratio; with both, the document is stretched to fill them, as the
rsvg package's `rsvg()` does.

## Examples

``` r
r <- svg_render('<svg xmlns="http://www.w3.org/2000/svg" width="16"
  height="16"><circle cx="8" cy="8" r="7" fill="tomato"/></svg>')
dim(r)
#> [1] 16 16
plot.new()
rasterImage(r, 0, 0, 1, 1)
```
