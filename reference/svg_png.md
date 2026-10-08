# Render an SVG document to PNG or JPEG

Renders as
[`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)
does and encodes the pixels with the bundled `stb_image_write`. The
output is the same bytes on every platform for the same document and
arguments.

## Usage

``` r
svg_png(x, file = NULL, ...)

svg_jpeg(x, file = NULL, quality = 90, background = "white", ...)
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

- file:

  `NULL` to return the encoded bytes, or a file path or a binary
  connection to write them to.

- ...:

  Arguments passed on to
  [`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)
  (all but `as`), and from there to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md).

- quality:

  JPEG quality, a whole number from 1 to 100.

- background:

  The colour the surface is cleared to before drawing: anything
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  takes, including `"transparent"`.

## Value

With `file = NULL`, a raw vector of the encoded image; otherwise `file`,
invisibly.

## Details

JPEG has no transparency, so `svg_jpeg()` clears the surface to white
unless told otherwise.

## Examples

``` r
icon <- '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
  <circle cx="8" cy="8" r="7" fill="tomato"/></svg>'
png <- svg_png(icon, width = 64)
png[1:8]
#> [1] 89 50 4e 47 0d 0a 1a 0a
path <- tempfile(fileext = ".jpg")
svg_jpeg(icon, path, quality = 80)
unlink(path)
```
