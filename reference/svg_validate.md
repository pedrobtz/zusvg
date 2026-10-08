# Check that a document loads

Loads `x` under the same limits as
[`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
and reports the outcome instead of raising it, for gating a batch of
untrusted files.

## Usage

``` r
svg_validate(x, ...)
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

`TRUE` if the document loads; otherwise the classed condition
[`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
would have raised (see
[zusvg-conditions](https://pedrobtz.github.io/zusvg/reference/zusvg-conditions.md)),
returned rather than signalled. An unusable argument is still an error.

## Examples

``` r
svg_validate('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>')
#> [1] TRUE
svg_validate("<svg><g></svg>")
#> <zusvg_parse_error in svg_validate("<svg><g></svg>"): not an SVG document plutosvg can load: malformed at byte 8>
```
