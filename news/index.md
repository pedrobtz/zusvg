# Changelog

## zusvg 0.1.0

First release.

- [`svg_load()`](https://pedrobtz.github.io/zusvg/reference/svg_load.md),
  [`svg_read()`](https://pedrobtz.github.io/zusvg/reference/svg_read.md),
  [`svg_size()`](https://pedrobtz.github.io/zusvg/reference/svg_size.md)
  and
  [`svg_validate()`](https://pedrobtz.github.io/zusvg/reference/svg_validate.md)
  load SVG from a string, raw vector, connection or file
  (gzip-compressed included) under limits on size, element count,
  nesting and embedded images.
- [`svg_render()`](https://pedrobtz.github.io/zusvg/reference/svg_render.md)
  draws a document, or one element by `id`, to a `nativeRaster`, an RGBA
  array or raw RGBA bytes, with `currentColor` and CSS
  [`var()`](https://rdrr.io/r/stats/cor.html) colours supplied from R;
  [`svg_extents()`](https://pedrobtz.github.io/zusvg/reference/svg_extents.md)
  measures.
- [`svg_png()`](https://pedrobtz.github.io/zusvg/reference/svg_png.md)
  and
  [`svg_jpeg()`](https://pedrobtz.github.io/zusvg/reference/svg_png.md)
  encode a render, returning bytes or writing a file or connection;
  [`svg_elements()`](https://pedrobtz.github.io/zusvg/reference/svg_elements.md)
  lists a document’s elements by `id`.
- Text and clip paths, which are not drawn, warn once per call
  (`zusvg_text_skipped`, `zusvg_clip_skipped`) unless `quiet = TRUE`.
- Hostile input is bounded: a render stops after a million element
  visits (`zusvg_limit_error`, `limit = "render_steps"`), a dashed path
  after a million segments, and embedded images larger than 4096 pixels
  a side are not decoded.
- Bundles plutosvg 0.0.8 and plutovg 1.3.3 with sixteen local patches,
  recorded in `src/vendor/PROVENANCE` and offered upstream: two planned
  (`<use>` depth, loader allocation checks), one for `<use>` of a
  `<symbol>`, eight for undefined behaviour, unbounded work and a hang
  that the fuzzer and the sanitizers found, and five for what R CMD
  check reports.
- A 64 by 64 icon loads and renders in about 0.1 ms; see
  `tools/run-benchmarks`.
- [`zusvg_info()`](https://pedrobtz.github.io/zusvg/reference/zusvg_info.md)
  reports the bundled versions, their upstream tags and commits, the
  patches and the limits.
