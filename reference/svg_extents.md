# Extents of a document or element

The bounding box of what the document, or one element, draws, in the
document's user units, as plutosvg computes it. This is what
[`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)
crops to when given `id`, and how an icon sheet is cut into icons.

## Usage

``` r
svg_extents(x, id = NULL, ...)
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

- id:

  The `id` of an element, or `NULL` for the whole document.

- ...:

  Passed on to
  [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md)
  when `x` is not already a document.

## Value

A named double vector `c(x = , y = , width = , height = )`. An element
that draws nothing has zero width and height.

## Examples

``` r
sheet <- '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">
  <circle id="a" cx="10" cy="10" r="8"/><rect id="b" x="24" y="4"
  width="12" height="12"/></svg>'
svg_extents(sheet)
#>      x      y  width height 
#>      2      2     34     16 
svg_extents(sheet, id = "b")
#>      x      y  width height 
#>     24      4     12     12 
```
