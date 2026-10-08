# zusvg 0.0.0.9000

* Bundles plutosvg 0.0.8 and plutovg 1.3.3 with seven local patches. `<use>`
  hops now count against the 256-level render depth. The loader fails
  cleanly when an allocation fails. Five smaller patches remove what R CMD
  check would report: three compiler warnings (one only in C23), a
  `sprintf()` call and a diagnostic-suppressing pragma.
* `svg_load()`, `svg_read()`, `svg_size()` and `svg_validate()` load SVG from
  a string, raw vector, connection or file (gzip-compressed included) under
  limits on size, element count, nesting and embedded images.
* `svg_render()` draws a document, or one element by `id`, to a
  `nativeRaster`, an RGBA array or raw RGBA bytes, with `currentColor` and
  CSS `var()` colours supplied from R; `svg_extents()` measures.
* A `<use>` of a `<symbol>` is sized by the `<use>` (patch 0008).
* `zusvg_info()` reports the bundled versions, their upstream tags and
  commits, and the patches.
