# Build information

Reports the bundled plutosvg and plutovg versions, the release tags and
commits they were vendored from, and the local patches applied to them.

## Usage

``` r
zusvg_info()
```

## Value

A list of class `zusvg_info` with elements:

- `plutosvg`, `plutovg`: each a list of `version` (the library's own
  version string, e.g. `"0.0.8"`), `tag` and `commit` (the upstream
  release the bundled copy was taken from).

- `patches`: identifiers of the local patches applied to the bundled
  copies, in order (see `src/vendor/PROVENANCE`).

- `image_formats`: the embedded image formats the bundled decoder reads.

- `smoke_ok`: `TRUE` if the bundled libraries load and render a known
  document correctly.

## Examples

``` r
zusvg_info()
#> <zusvg_info>
#> plutosvg:  0.0.8 (v0.0.8, fd8a080b3d0b)
#> plutovg:   1.3.3 (v1.3.3, bbd91f0d06a7)
#> patches:   0001-use-depth, 0002-loader-alloc-checks, 0003-stbtt-def-guard, 0004-stroker-unused-point, 0005-stbiw-snprintf, 0006-stbtt-no-pragmas, 0007-bsearch-const, 0008-use-symbol-size, 0009-render-step-budget, 0010-ft-coord-clamp, 0011-stbi-idct-wide, 0012-dash-budget, 0013-stroker-empty-border, 0014-stbiw-jpg-unsigned-bits, 0015-use-ancestor-cycle, 0016-blend-defined-casts
#> images:    png, jpeg
#> self-test: ok
```
