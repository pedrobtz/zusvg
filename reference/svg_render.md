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
  as = "native",
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

  Not yet supported: must be `NULL`.

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

  Not yet supported: must be `NULL`.

- as:

  The form of the result: only `"native"` so far, a `nativeRaster` that
  [`grid::rasterGrob()`](https://rdrr.io/r/grid/grid.raster.html) and
  [`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html)
  draw without conversion.

- max_pixels:

  The most pixels the surface may have, at most `2^29 - 1`, or `Inf` for
  that.

- quiet:

  Reserved: will silence the warning for text that does not render.

- ...:

  Passed on to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  when `x` is not already a document.

## Value

For `as = "native"`, a `nativeRaster`: an integer matrix of packed,
non-premultiplied colours with `dim = c(height, width)`.

## Details

The surface size: with neither `width` nor `height`, the document's size
([`svg_size()`](https://pedrobtz.github.io/zusvg/reference/svg_size.md))
times `scale`, rounded up; with one, the other follows the document's
aspect ratio; with both, the document is stretched to fill them, as
[`rsvg::rsvg()`](https://docs.ropensci.org/rsvg/reference/rsvg.html)
does.

## Examples

``` r
r <- svg_render('<svg xmlns="http://www.w3.org/2000/svg" width="16"
  height="16"><circle cx="8" cy="8" r="7" fill="tomato"/></svg>')
dim(r)
#> [1] 16 16
plot.new()
rasterImage(r, 0, 0, 1, 1)
```
