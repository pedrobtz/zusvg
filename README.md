# zusvg

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zusvg/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zusvg/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zusvg/main/.github/badges/coverage.svg)](https://github.com/pedrobtz/zusvg/actions/workflows/coverage.yaml)
<!-- badges: end -->

zusvg renders SVG icons and logos to pixels: a `nativeRaster` for grid and
base graphics, an RGBA array, raw RGBA bytes, or a PNG or JPEG file. It
bundles two small C libraries, [plutosvg](https://github.com/sammycage/plutosvg)
and [plutovg](https://github.com/sammycage/plutovg), so it installs from source
on every platform with no system library: no librsvg, no cairo, no Rust
toolchain. The same document gives the same pixels everywhere.

It is meant for icons and logos. It does not render text, filters, masks,
patterns, markers, CSS style sheets or clip paths; a document that uses them
renders without them, and text and clips warn. For plots, diagrams and
badges, which mostly need text, use [rsvg](https://docs.ropensci.org/rsvg/).

## Installation

``` r
# install.packages("pak")
pak::pak("pedrobtz/zusvg")
```

## Example

``` r
library(zusvg)

icon <- '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
  fill="none" stroke="currentColor" stroke-width="2">
  <path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>'

r <- svg_render(icon, width = 64, color = "steelblue")   # a nativeRaster
plot.new(); rasterImage(r, 0, 0, 1, 1)

svg_png(icon, "house.png", width = 128)                   # a PNG file
a <- svg_render(icon, width = 64, as = "array")           # the shape rsvg's rsvg() returns
```

`svg_load()` checks untrusted input under limits on size, element count,
nesting and embedded images before the renderer sees a byte;
`svg_elements()` and `svg_render(id = )` cut an icon sheet into icons; and
`palette` answers CSS `var()` colours. See the vignette,
`vignette("zusvg")`.

## Licence

MIT. plutosvg and plutovg are MIT; plutovg contains FreeType-derived code
under the FreeType Licence and the stb libraries; see `inst/COPYRIGHTS`.
