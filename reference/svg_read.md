# Read an SVG file

Reads a file, URL or connection whole and loads it as
[`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
does. A gzip-compressed file (`.svgz`) is decompressed. At most
`max_size + 1` bytes are ever read, so an oversized file or an endless
connection fails with `zusvg_limit_error` rather than exhausting memory.
This is the only function that takes a path.

## Usage

``` r
svg_read(file, width = NULL, height = NULL, ...)
```

## Arguments

- file:

  A file path, a URL or a connection.

- width, height:

  The container size in CSS pixels that a root `width="100%"` resolves
  against. `NULL`, the default, falls back to the `viewBox`, then to 300
  by 150, as plutosvg does.

- ...:

  The limits and `images`, passed on to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md).

## Value

An `svg_document`, as
[`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md).

## Details

A string with an `http`, `https`, `ftp`, `ftps` or `file` scheme is read
with [`url()`](https://rdrr.io/r/base/connections.html), any other
string as a file path. A connection that is not open is opened in `"rb"`
mode and closed afterwards; an open one must be binary, is read from its
current position, and is left open.

## Examples

``` r
path <- tempfile(fileext = ".svg")
writeLines('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>', path)
svg_read(path)
#> <svg_document> 8 x 8, 1 element
unlink(path)
```
