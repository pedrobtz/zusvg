# Size of an SVG document

The intrinsic size plutosvg resolves for the document: the root's
`width` and `height` against the container size given at load, else the
`viewBox`, else 300 by 150.

## Usage

``` r
svg_size(x, ...)
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

- ...:

  Passed on to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  when `x` is not already a document.

## Value

A named double vector, `c(width = , height = )`, in CSS pixels.

## Examples

``` r
svg_size('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 24"/>')
#>  width height 
#>     48     24 
```
