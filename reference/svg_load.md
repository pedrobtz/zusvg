# Load an SVG document

Checks the input under the limits, then parses it with plutosvg into a
document that the rendering and measuring functions take. Every one of
them also accepts what `svg_load()` accepts, loading it on the way, so
calling `svg_load()` first is only needed to load once and render many
times, or to set the container size.

## Usage

``` r
svg_load(
  x,
  width = NULL,
  height = NULL,
  ...,
  max_size = 64 * 1024^2,
  max_elements = 1e+05,
  max_depth = 256,
  images = TRUE
)
```

## Arguments

- x:

  The document: a raw vector of its bytes, a single string holding its
  text, or a connection to read it from. gzip-compressed bytes (an
  `.svgz` file's) are decompressed, with `max_size` bounding the
  decompressed size.

- width, height:

  The container size in CSS pixels that a root `width="100%"` resolves
  against. `NULL`, the default, falls back to the `viewBox`, then to 300
  by 150, as plutosvg does.

- ...:

  Must be empty; it forces the limits to be named.

- max_size:

  The most bytes read from any source, and the most a compressed input
  may decompress to; at most `2^31 - 1`, or `Inf` for that.

- max_elements:

  The most start tags the document may have.

- max_depth:

  The deepest the document's elements may nest.

- images:

  If `FALSE`, a document with an `<image>` element is refused before
  anything decodes it: use it for untrusted input.

## Value

An `svg_document`: an object holding the loaded document.
[`print()`](https://rdrr.io/r/base/print.html) shows its size and
element count, and [`dim()`](https://rdrr.io/r/base/dim.html) gives
`c(height, width)` rounded up, as
[`svg_size()`](https://pedrobtz.github.io/zusvg/reference/svg_size.md)
reports them.

## Details

A character `x` is always the document's text, never a file path: read a
file with
[`svg_read()`](https://pedrobtz.github.io/zusvg/reference/svg_read.md).

## See also

[zusvg-conditions](https://pedrobtz.github.io/zusvg/reference/zusvg-conditions.md)
for the errors it raises.

## Examples

``` r
doc <- svg_load('<svg xmlns="http://www.w3.org/2000/svg" width="24"
  height="24"><circle cx="12" cy="12" r="10"/></svg>')
doc
#> <svg_document> 24 x 24, 2 elements
dim(doc)
#> [1] 24 24
```
