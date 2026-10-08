# Elements of an SVG document

Lists the elements that have an `id`, among those plutosvg draws, with
what will not render inside each. It is the tool for cutting an icon
sheet into icons with
[`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)'s
`id`, and for deciding whether zusvg can draw a file.

## Usage

``` r
svg_elements(x, ...)
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

A data frame, one row per element with an `id`, in document order:

- `id`: the element's `id`.

- `tag`: its element name, such as `"g"`, `"symbol"` or `"path"`.

- `has_text`: whether it contains text, which does not render.

- `has_clip`: whether it, or something inside it, uses a clip path that
  would change the picture. Clip paths are not applied (see
  [`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)).

When two elements share an `id`, plutosvg finds the last one.

## Examples

``` r
svg_elements('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">
  <g id="a"><circle cx="10" cy="10" r="8"/></g>
  <g id="b"><text x="24" y="14">B</text></g></svg>')
#>   id tag has_text has_clip
#> 1  a   g    FALSE    FALSE
#> 2  b   g     TRUE    FALSE
```
