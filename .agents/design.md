# zusvg — Design

**Status:** Draft, 2026-10-08. Adopted from [RFC 0007](https://github.com/pedrobtz/packages/blob/main/rfcs/0007-zusvg-svg-rasteriser.md) (2026-10-07) as the package's own specification. Nothing here is implemented: the repository is the `usethis` skeleton plus these documents. Every statement here is a decision; things not yet decided live in §18, and §20 lists every place a later stage settles a detail (D4's patch content, the Stage 0 checks in §7 and §9). Amend this file in the same commit as the code that changes it. [roadmap.md](roadmap.md) sequences the work; its section references (§) point here.
**Package:** `zusvg`
**One line:** SVG documents rendered to `nativeRaster`, RGBA arrays, PNG or JPEG through vendored plutosvg and plutovg, with a pre-scan that bounds untrusted input, so that icons and logos render identically on every platform with no system library.

What changed between the RFC and this document: the RFC read the plutosvg and plutovg sources but built nothing. On 2026-10-08 the upstream release pages and `plutosvg.h` were re-read and the sibling checkouts consulted; where that changes a fact or adds a Stage 0 check it is marked *verified 2026-10-08* (§3, §9, §17). Later the same day the full v0.0.8 and v1.3.3 source trees and the sibling repositories were read against this document; facts that changed then are marked *read 2026-10-08*. That reading found that plutosvg does not apply `<clipPath>`, that its 256-level depth cap does not cover `<use>`, that its `*_BUILD` macros export the API past `-fvisibility=hidden`, and that the `zsv_` prefix belongs to zucsv's vendored zsv library. The RFC's roadmap table (its §19) became [roadmap.md](roadmap.md).

---

## 1. What zusvg is

`zusvg` turns an SVG document into pixels: a native raster for `grid` and `graphics`, an RGBA array, or a PNG or JPEG file, with the width, height, element and colour variables chosen by the caller. It does this with two small C libraries compiled into the package, so it installs from source on every platform CRAN builds for, with no `pkg-config`, no `librsvg2-dev`, no Homebrew bottle and no Rtools toolchain package.

The audience is the people who use `rsvg` today for icons, logos, plot-element sprites, `ggplot2` annotations, `magick` pipelines and Shiny or R Markdown assets, and who hit `rsvg`'s install failure wherever there is no CRAN binary: a source install on Linux needs `librsvg2-dev` and its stack (cairo, pango, GObject), which containers, HPC hosts and locked-down machines often lack, and R-devel or a fresh R release on macOS and Windows waits for binaries. For them zusvg is a drop-in: the same inputs, the same output shapes (§6), far fewer SVG features (§2). For the rest, who need text, filters, CSS or fonts, `rsvg` and `magick` stay the answer, and §3 says so.

---

## 2. Scope

**In, for v0.1.0:**

- Rendering an SVG document from a raw vector, a character string, a file or a connection to a surface of chosen size, scaled uniformly with `preserveAspectRatio` honoured, at a chosen background.
- Rendering one element by `id`, and measuring a document or element (`svg_extents()`), which is how an icon sheet becomes many icons.
- `currentColor` and CSS `var()` colours supplied from R, which is how icon sets are recoloured.
- Output as `nativeRaster`, RGBA double array, raw RGBA bytes, PNG or JPEG, each written by project or vendored code.
- Validation (`svg_validate()`) that loads without rendering and reports what the loader refused.
- Limits on input size, element count, nesting depth and pixel count, because an SVG from a web page or a message is untrusted input.

**Out, by the library's design and so by zusvg's:**

- `<text>` and `<tspan>`: plutosvg has no text support and no font dependency (§9). Documents with text render without it; §6.4 says how that is reported.
- `<filter>`, `<mask>`, `<pattern>`, `<marker>`, `<style>` sheets, `class` and CSS selectors, animation, scripting, external references: not implemented by plutosvg. Unknown elements are skipped with their subtree, as the library does. The `style=""` attribute is parsed for presentation properties (*read 2026-10-08*), so inline styles do work.
- `<clipPath>` and the `clip-path` property, for now: plutosvg 0.0.8 parses `<clipPath>` but marks it `TODO` and never applies it (*read 2026-10-08*: `plutosvg.c:23`; the attribute is parsed and unused), so clipped content renders unclipped. For 0.1.0, a document whose clip is not a full-canvas rectangle warns (§6.4); the patch that applies clips follows after 0.1.0 (D15).
- Embedded images other than base64 `data:` URIs holding PNG or JPEG, which is all plutosvg resolves; no file or network references.
- Vector output (PDF, PostScript, SVG-to-SVG) that `rsvg` offers through cairo: zusvg has no cairo and does not emulate it.
- An R graphics device that writes SVG. That is a different package (an `svglite` peer) and a different library.

---

## 3. Position in the `zu*` family

| Package | Library | Install needs | Text | Filters, CSS |
|---|---|---|---|---|
| `rsvg` (2.7.0, 2025-09-08; *verified 2026-10-08*) | librsvg2 ≥ 2.52 (Rust) | system library | yes | yes |
| `magick` | ImageMagick | system library | via rsvg | partial |
| `zusvg` | plutosvg (C) | nothing | no | no |

`rsvg` renders the full SVG 1.1 static subset through librsvg, which since 2.52 is written in Rust and links GObject, cairo, pango, freetype and libxml2; installing the R package from source means installing those first, and the CRAN binaries lag the library. `magick` reads SVG through ImageMagick's delegate, which is librsvg again where present and ImageMagick's own MSVG renderer where not, with different output on each machine. zusvg trades every feature in the last two columns for a build that cannot fail and output that is the same on every platform, which is what icon and logo rendering needs and what the family's other packages promise for their formats.

These are zusvg's cells for the family table that alignment rule R1 of [`zu-family-alignment.md`](https://github.com/pedrobtz/packages/blob/main/zu-family-alignment.md) places in `pedrobtz/packages` as `zu-family.md` (not yet written on 2026-10-08):

| | zusvg |
|---|---|
| Role | engine (the first in the family whose vendored library draws) |
| R prefix | `svg_` |
| Info function | `zusvg_info()` |
| Root condition class | `zusvg_error`; warnings `zusvg_warning` |
| Public C prefix | none; internal `zsg_` / `ZSG_` |
| From C | no C API |
| Hides symbols (`$(C_VISIBILITY)`) | yes, from Stage 0 (R3); plutovg's and plutosvg's symbols included |
| Vendored code | plutosvg 0.0.8, plutovg 1.3.3 (§9) |
| `LinkingTo` | `zufast (>= 0.1.0)`; `zukomp` from Stage 6 (its C API, for PNG's zlib stream) |
| `Imports` | `grDevices`; `zukomp` from Stage 6 (so that its callables are registered) |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

Within the family it adopts conventions rather than setting any: the vendor rules of zucbor (§13 there) and the template's "Vendored native code" section, alignment rules R1 to R3 and R10, classed conditions, tests on class. It consumes `zufast` for UTF-8 validation of the input (`zuf_utf8_valid()`, *verified 2026-10-08*) and for number formatting in messages, and nothing from `zubin`, `zuxml` or `zucbor`: plutosvg brings its own XML-shaped tokenizer and zusvg does not parse SVG itself. A later `svg_document()` accessor over `zuxml` is §18. `zukomp` (*verified 2026-10-08*: it exports `komp_compress()`, `komp_decompress()`, `komp_detect()`) supplies gzip for `.svgz` from R, and from Stage 6 the zlib stream inside PNG's `IDAT` through its C API (`inst/include/zukomp-r.h`, `R_GetCCallable()`; *read 2026-10-08*). PNG needs zukomp's `zlib` codec, not raw deflate, because `IDAT` is a zlib stream and `stb_image_write`'s hook must return one (§7). The internal prefix is `zsg_`: `zsv_` was the RFC's choice, but zucsv vendors the zsv CSV library, which defines about 160 `zsv_*` and `ZSV_*` identifiers (*read 2026-10-08*), and `zsg_` occurs in no sibling.

**The feature survey** (Stage 0, 2026-10-08; §18 Q6). It counted files containing each feature plutosvg 0.0.8 does not render.

| Corpus | Files | Text, filter, mask, pattern, marker, `<style>` | Clip paths | Any unsupported feature |
|---|---|---|---|---|
| Font Awesome Free 7.3.1 | 2 883 | 0% | 0% | 0% |
| Bootstrap Icons 1.13.1 | 2 078 | 0% | 0% | 0% (`class=` everywhere, never with a `<style>`) |
| Material Design Icons 0.14.15, five styles | 10 610 | 0% | 0.01% (one no-op) | 0.01% |
| Lucide 1.53.0 | 2 133 | 0% | 0% | 0% (`class=` everywhere, never with a `<style>`) |
| SVGs in 94 installed R packages | 688 | text 92%, `<style>` 20% | 77% | 97% |

Every Font Awesome, Bootstrap and Lucide icon depends on `currentColor`; none uses `var(--`, `<image>` or `<foreignObject>`. Three kinds of file account for the R-package corpus:

- Lifecycle badges are 513 of its 688 files. Each is text on a pill whose clip only rounds the corners.
- Terminal recordings (callr, cli, pak and others) are text and a `<style>` sheet.
- `svglite` plots need their `<style>` rules even to stroke a line.

Clip paths alone change the picture in 8 of 688 R-package files (hex-sticker logos and plot panels). About 97% of the clips found are a full-canvas rectangle, which changes nothing. So the audience of §1 holds for icons and logos and does not extend to R-generated plots, badges or diagrams. D3 stands, and §1 and the package help page say what the audience is not. Clip paths are D15.

**Consumers.** None named; RFC 0008 §18 names "zusvg paths into content streams" as a later possibility for `zupdf`. Nothing in 0.1.0 is shaped around it.

---

## 4. Architecture

Three layers, like zucbor's check, build and encode:

1. **Pre-scan** (`src/zsg_scan.c`, R-free behind `zsg_scan.h`): one pass over the input bytes that validates UTF-8 (`zuf_utf8_valid()`), counts start tags and their nesting depth, finds `<image` and `<text` elements, and enforces the limits of §12 before plutosvg sees a byte. For `svg_elements()` (§5) it also records, for each element among the seventeen tags plutosvg builds and outside a skipped subtree, its tag, its `id` attribute if any, and whether its subtree holds `<text`; reading the `id` attribute is the only attribute parsing it does, and it uses plutosvg's attribute rules, so an id the list shows is an id `plutosvg_document_extents()` finds. It does not otherwise parse SVG; it tracks `<`, `>`, `/>`, comments, CDATA and DOCTYPE exactly as plutosvg's loader does (§9), so what it counts is what plutosvg will build. The fuzz target (§15) runs this layer alone and with the loader.
2. **Document** (`src/zsg_doc.c`): `plutosvg_document_load_from_data()` over a copy of the bytes that the document owns, wrapped in a finalized external pointer of class `svg_document`. The copy is needed because plutosvg keeps pointers into the buffer for the document's life; a raw vector could be freed or moved by R.
3. **Render** (`src/zsg_render.c`): a `plutovg_surface_t` of the requested size, a canvas, the palette callback that answers CSS `var()` names from a C array prepared from a named R character vector, then the conversion of the surface's premultiplied native-endian ARGB (§6.2) into the requested R object.

R code (`R/`) does argument checking, source reading (file, connection, raw, character), output dispatch and the `print()` and `dim()` methods. Every `.Call` entry point is registered (`R_forceSymbols`), symbols are hidden (`PKG_CFLAGS = $(C_VISIBILITY)`), and plutovg's and plutosvg's own symbols are confined to the shared object the same way. That needs `-DPLUTOVG_BUILD_STATIC -DPLUTOSVG_BUILD_STATIC` and not `-DPLUTOVG_BUILD -DPLUTOSVG_BUILD`: with `*_BUILD` and no `*_BUILD_STATIC`, the headers mark every API function `__attribute__((visibility("default")))`, which overrides `-fvisibility=hidden`, and on Windows `__declspec(dllexport)` (*read 2026-10-08*: `plutosvg.h:28-46`, `plutovg.h:32-50`). `tools/check-symbols` verifies that only `R_init_zusvg` is exported.

No static state. plutovg has none that zusvg touches (its only globals are `const` tables; its font cache and mutex, §9, are not used), so two documents render independently. One document is not re-entrant: `render_use()` writes the referenced element's `parent` during a render and restores it afterwards (*read 2026-10-08*: `plutosvg.c:2168`), so one document must not render on two threads at once. R calls are serial, so this binds only a future C caller. A render interrupted by R leaves nothing behind: every plutovg object made during a call is destroyed on the normal path and by the external pointer's finalizer on the error path.

---

## 5. Public R API (complete v0.1.0 surface)

```r
svg_load(x, width = NULL, height = NULL, ..., max_size = 64 * 1024^2,
         max_elements = 1e5, max_depth = 256, images = TRUE)
svg_read(file, width = NULL, height = NULL, ...)
svg_validate(x, ...)                       # TRUE, or a classed condition

svg_render(x, width = NULL, height = NULL, id = NULL, scale = 1,
           background = "transparent", color = "black", palette = NULL,
           as = c("native", "array", "raw"), max_pixels = 5e7,
           quiet = FALSE, ...)
svg_png(x, file = NULL, ...)               # raw PNG, or writes file
svg_jpeg(x, file = NULL, quality = 90, background = "white", ...)

svg_extents(x, id = NULL, ...)             # c(x, y, width, height)
svg_size(x, ...)                           # c(width, height) intrinsic
svg_elements(x, ...)                       # data frame: id, tag, has_text

zusvg_info()
```

Every rendering and measuring function takes as `x` an `svg_document` from `svg_load()` or `svg_read()`, or what `svg_load()` accepts: a raw vector, a single character string holding the document, or a connection. A path is a file only through `svg_read()`, as `xml_read()` and `cbor_read()` in the siblings, so a string can never be mistaken for a path. The `...` of the rendering and measuring functions are passed to `svg_load()` when `x` is not already a document, and are an error when it is. They carry the limits and `images` only: `svg_render()` uses `width` and `height` for the surface, so a container size for a root `width="100%"` is given by calling `svg_load()` first.

- `width`, `height` (load): the container size in CSS pixels that resolves a root `width="100%"`; `NULL` is plutosvg's `-1`, which falls back to the `viewBox` and then to 300 by 150.
- `width`, `height` (render): the surface size in pixels. The box being rendered is the document's intrinsic size (`svg_size()`) without `id` and the element's extents (`svg_extents(x, id)`) with it, as in plutosvg's own `render_to_surface()` (§6.1). One size given scales the other by that box's ratio; neither given uses the box times `scale`, rounded up. Both given stretch, as `rsvg()` does, because callers who want a fixed canvas expect that.
- `id`: an element to render alone, cropped to its own extents; an unknown id is `zusvg_missing_element`.
- `background`: any R colour, including `"transparent"`; the surface is cleared to it before drawing, so JPEG output defaults to white.
- `color`: the value of `currentColor`, an R colour.
- `palette`: a named character vector of R colours, answering CSS `var(--name)` by name without the `--`; a name not present leaves the variable unresolved, as the library does.
- `as`: `"native"` is a `nativeRaster` (integer matrix, R's packed ABGR; `grid::rasterGrob()` and `graphics::rasterImage()` take it without conversion); `"array"` is a `height x width x 4` double array in `[0, 1]`, non-premultiplied, the shape `rsvg::rsvg()` returns, with `as.raster()` working; `"raw"` is a raw vector with `dim = c(4, width, height)`, RGBA interleaved, the shape `rsvg::rsvg_raw()` returns and `magick::image_read()` takes. (`png::writePNG()` takes the `"native"` and `"array"` forms.)
- `svg_png()` and `svg_jpeg()` take the render arguments after `file`; with `file = NULL` they return the encoded bytes as a raw vector.
- `svg_validate()` loads under the same limits and returns `TRUE` or the condition it would have raised, without raising it; it is for gating a batch.
- `svg_elements()` lists the elements with an `id`, their tag and whether their subtree contains text that will not render; it is the tool for icon sheets and for deciding whether zusvg can draw a file.
- `zusvg_info()`: plutosvg and plutovg versions, the vendored commits and patch identifiers, the `stb_image` formats compiled in, the limits' defaults.

`print.svg_document` shows the intrinsic size and element count; `dim()` returns `c(height, width)` rounded up, matching `dim()` of what `svg_render(as = "native")` returns at `scale = 1`.

---

## 6. SVG to pixels

### 6.1 Size and placement

plutosvg resolves the root's `width` and `height` against the container size given at load, falls back to a valid `viewBox`, then to 300 by 150, and refuses a document whose intrinsic size is not positive (*read 2026-10-08*: `plutosvg.c:1452-1473`; a root `width="0"` with a `viewBox` takes the `viewBox`'s size rather than failing). zusvg exposes exactly that: `svg_size()` is the resolved intrinsic size (`plutosvg_document_get_width()`, `_get_height()`), and `svg_extents()` the bounding box of the drawn content of the document or an element (`plutosvg_document_extents()`, which renders in a bounding mode). The render's box is the intrinsic size without `id` and the element's extents with it, and the render scales from box to surface with `plutovg_canvas_scale()` and a translate. That is what the library's own `render_to_surface()` does (*read 2026-10-08*: `plutosvg.c:2613-2615` starts from `{0, 0, width, height}` and calls `extents()` only for an `id`), so a whole-document render keeps the viewport, as `rsvg` does, and is not cropped to content. zusvg calls `plutosvg_document_render()` on its own canvas rather than `plutosvg_document_render_to_surface()`, because the latter cannot take a background or a stretch (*verified 2026-10-08* against `plutosvg.h` 0.0.8: `render_to_surface()` takes `id`, `width`, `height`, `current_color`, `palette_func` and `closure` only).

zusvg computes pixel sizes in R as doubles and checks them before any allocation or conversion to `int`: finite, at least 1, each below plutovg's own limit of 32768, and `width * height` within `max_pixels` (§12). plutovg cannot be left to check: `render_to_surface()`'s `(int)ceilf(w)` is undefined for a document with `width="1e30"`, and `plutovg_surface_create()` clears the buffer with `memset(data, 0, height * stride)`, an `int` product that overflows past 2^31 bytes, about 23170 by 23170 (*read 2026-10-08*: `plutovg-surface.c:33`; there is no overflow check). `max_pixels` is therefore itself capped below 2^29 pixels, so that the surface's byte count fits in an `int`.

### 6.2 Pixel format

plutovg surfaces hold 32-bit premultiplied ARGB in native endian, with `plutovg_convert_argb_to_rgba()` provided for the straight RGBA byte order. zusvg uses that conversion for `"raw"` and `"array"`, and for `"native"` too, because R's `nativeRaster` is not premultiplied. On a little-endian machine straight RGBA bytes read as a 32-bit integer are R's packed ABGR, so the conversion writes straight into the `nativeRaster`'s integer buffer; a big-endian build swaps each word. The un-premultiply is lossy for low-alpha pixels, which is one reason the `rsvg` cross-check (§15) uses a tolerance and zusvg's own pinned values do not.

### 6.3 Colours

R colours go through `grDevices::col2rgb(alpha = TRUE)` in R, so every name, `#rrggbbaa` and `rgb()` R accepts works for `background`, `color` and `palette`; the C side only ever sees four floats.

### 6.4 What does not render

A document is never refused for using a feature plutosvg lacks: the library skips what it does not know, and an icon with a stray `<title>` must still render. But text is the feature callers will miss, so the pre-scan records whether `<text` occurs and each rendering call (`svg_render()`, `svg_png()`, `svg_jpeg()`) signals one `zusvg_text_skipped` warning for its document, with the count, unless `quiet = TRUE`. The warning is classed, so `suppressWarnings(classes = "zusvg_text_skipped")` works on every R zusvg supports (the argument arrived in R 4.0.0). Clip paths (§2) warn the same way, as `zusvg_clip_skipped`, unless every clip the document references is a full-canvas rectangle, which changes nothing (D15).

---

## 7. Pixels to files

PNG and JPEG are written by plutovg's vendored `stb_image_write` (v1.16) through `plutovg_surface_write_to_png_stream(surface, write_func, closure)` and `plutovg_surface_write_to_jpg_stream(surface, write_func, closure, quality)` (*read 2026-10-08*: `plutovg.h:1277,1288`), into a growable buffer owned by an external pointer, then copied to a raw vector or written with R's connections. Both functions convert the surface to RGBA in place and back, so they need a surface the caller owns. `stb_image_write`'s PNG encoder produces valid but poorly compressed files. Stage 6 replaces its compressor through stb's `STBIW_ZLIB_COMPRESS` hook with `zukomp`'s `zlib` codec, reached through zukomp's C API, once zukomp is on CRAN. Three constraints apply:

- The hook must return a zlib stream, not raw deflate.
- Its result is released with `STBIW_FREE()`, which is `free()`.
- It runs inside plutovg's frames, so the zukomp callable it uses must return a status and never raise an R error (§13).

Defining the hook from the compiler line also needs its prototype visible in `plutovg-surface.c`, which is a one-line patch (D4). The output stays byte-identical across platforms either way.

---

## 8. Determinism

The same document, arguments and zusvg version produce the same bytes on every platform. plutovg's rasteriser is integer fixed-point (FreeType's `ft-raster` and `ft-stroker`, §9) once coordinates reach 26.6 fixed point through `roundf(x * 64)`, so this is plausible, and the conformance job (§15) checks it across Linux, macOS and Windows runners, x86-64 and arm64, by hashing the rendered fixtures. If a platform differs, the cause is found or the claim is withdrawn in the same commit; it is not left as a flaky test.

The known threat is floating-point contraction. Matrix mapping, dash flattening, gradients and textures are plain `float` expressions such as `a*b + c` (*read 2026-10-08*: `plutovg-matrix.c:68-73`, `plutovg-blend.c`). Neither library has `#pragma STDC FP_CONTRACT OFF` or `-ffp-contract=off`. Clang contracts by default, and GCC does in its GNU modes, which R uses. So an arm64 build can emit fused multiply-adds where an x86-64 build without `-mfma` cannot, and one ULP at the 26.6 rounding moves an edge pixel. `-ffp-contract=off` is not a portable `Makevars` flag. Stage 2 measures whether this occurs, and §18 Q9 holds the response. Because CRAN's machines are not zusvg's CI, the tests that run on CRAN compare pixels within a tolerance; exact hashes are checked in the conformance job and under `skip_on_cran()` (§15).

---

## 9. The vendored libraries, as zusvg uses them

| Library | Pin (*verified 2026-10-08*: each is upstream's latest release) | Files | Lines | Licence |
|---|---|---|---|---|
| plutosvg | v0.0.8 | `source/plutosvg.c`, `.h` (`plutosvg-ft.h` is not compiled in) | 2.9 k | MIT |
| plutovg | v1.3.3 | 11 `.c` and 9 `.h` in `source/`, `include/plutovg.h` | 9.5 k in `.c`; 28.6 k with the `stb` headers | MIT; FTL parts; `stb` public domain or MIT |

Facts read from the source that shape the design:

- **Loader.** `plutosvg_document_load_from_data(data, length, width, height, destroy_func, closure)` (`length = -1` means `strlen()`) is a single iterative loop over the bytes: it skips a BOM, the XML declaration, comments, CDATA and a DOCTYPE with its internal subset, builds elements for the seventeen tags it knows (`svg`, `g`, `defs`, `symbol`, `use`, `image`, `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `linearGradient`, `radialGradient`, `stop`, `clipPath`), and skips any other element with its subtree. Entities are not expanded (there is no `&` handling at all), so there is no entity-expansion attack. It returns `NULL` on any error with no reason, which is why zusvg's pre-scan exists: to reject the cases it can name before the loader rejects them silently. On that failure path it has already called `destroy_func(closure)` (*read 2026-10-08*: `plutosvg.c:1173,1478`), so zusvg's copy of the bytes is released by the callback and never freed a second time. Attribute values and ids point into `data` for the document's life (`plutosvg.h:92`), hence the copy (§4).
- **Allocation.** Elements and attributes are bump-allocated from chunked heaps whose `malloc()` is unchecked (`heap_alloc()`), so an out-of-memory condition is a null dereference, not a `NULL` return. The same holds for `heap_create()`, `document_create()` and `hashmap_create()` in plutosvg, and for `plutovg_canvas_create()`, `plutovg_path_create()` and the array `realloc` macro in `plutovg-utils.h` (*read 2026-10-08*). zusvg's `max_size` and `max_elements` bound what the heaps can grow to. Patch `0002-loader-alloc-checks` makes every plutosvg loader allocation fail through the loader's own error path, so the load returns `NULL` (§17 D4). plutovg's growth arrays (`plutovg_array_ensure()`) are left unchecked: they have no failure path, and adding one touches every caller. What they grow to is bounded by `max_pixels` and the path complexity `max_size` allows, and Stage 5's allocation-failure job tests what is left.
- **Rendering recursion.** `render_element()` recurses once per nesting level and once per `<use>` hop. `has_cycle_reference()` stops a `<use>` that refers to an element already on the render stack. 0.0.8's `MAX_RENDER_DEPTH` of 256 is counted only in `render_children()`; `render_use()` calls `render_element()` on its target directly, so the counter does not move (*read 2026-10-08*: `plutosvg.c:2168-2176`, `2571-2580`). The consequences:
  - A chain of distinct `<use>` elements (a→b→c→…) recurses on the C stack to the chain's length, uncapped. A file of about a megabyte can overflow the stack.
  - Fan-out (§12) is not bounded either.
  - The pre-scan's `max_depth` bounds lexical nesting only.

  D4's depth patch is therefore required. It counts `<use>` hops against the same depth as `render_children()`.
- **Images.** `<image href>` resolves only base64 `data:image/png`, `data:image/jpg` and `data:image/jpeg` URIs (`plutosvg.c:2460-2467`), decoded by plutovg's vendored `stb_image` 2.30 (`STBI_rgb_alpha`), whose JPEG and PNG decoders have a history of CVEs. zusvg compiles with `-DSTBI_NO_BMP -DSTBI_NO_PSD -DSTBI_NO_TGA -DSTBI_NO_GIF -DSTBI_NO_HDR -DSTBI_NO_PIC -DSTBI_NO_PNM`, which `stb_image` honours from the compiler line without editing the file (each is `#ifdef`-tested). `images = FALSE` makes the pre-scan refuse any `<image` element before decoding. `STBI_NO_STDIO` and `STBI_WRITE_NO_STDIO` must not be set, because `plutovg-surface.c` calls the stdio entry points and would not compile. `STBI_NO_THREAD_LOCALS` is set. Under emulated thread-local storage (GCC on macOS, MinGW on Windows), stb_image's thread-local failure reason links libgcc's `__emutls_*` helpers, which reference `abort()` and are exported from the shared object (*found at Stage 0*). The fuzz corpus includes embedded images.
- **Surfaces.** `plutovg_surface_create()` refuses a dimension at or above 32768 (`kMaxSize = 1 << 15`) and returns `NULL` on `malloc()` failure, which zusvg reports as `zusvg_memory_error`. It has no overflow check on `height * stride` (*read 2026-10-08*, correcting the RFC's reading of the 1.3.3 notes); §6.1 says how zusvg keeps sizes inside it.
- **`<use>` of a `<symbol>` ignored the `<use>`'s size** (*found at Stage 2*; patch `0008` fixes it, D17). `render_use()` passes only `x` and `y`. `render_svg()` then sizes a `<symbol>` from the symbol's own `width` and `height`, which default to 100% of the viewport, never from the `<use>`. An icon sprite sheet's `<use href="#icon" width="24" height="24"/>` therefore draws the icon viewport-sized. The `use-symbol` fixture pins it; §18 Q10.
- **Clip paths.** `TAG_CLIP_PATH` carries a `TODO`, and nothing in the renderer reads `clip-path` (*read 2026-10-08*). §2 and D15.
- **Fonts.** plutovg's `plutovg-font.c` carries `stb_truetype`, a font face cache, a mutex and a system font directory scan. The file cannot be left out, because `plutovg-canvas.c` calls into it. plutosvg never calls any font function. The mutex is a `CRITICAL_SECTION` under `_WIN32` (with `windows.h`), C11 `mtx_t` under `HAVE_THREADS_H`, and a no-op otherwise. zusvg does not define `HAVE_THREADS_H`, and it defines `PLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD`, which compiles out the directory scan and its `mmap()` and `dirent` use, so nothing reads the file system. The symbols are hidden with the rest.
- **Standard and libraries.** plutosvg builds as C99 and plutovg as C11 (`gnu11` in its Meson file); both need `-lm` and nothing else. R's default C standard is C17 or later, so `src/Makevars` sets nothing.
- **Linkage of the stb APIs.** plutovg includes each stb header with `static` linkage. Static stb functions that plutovg never calls (68 of them) each draw `-Wunused-function` under `-Wall`, and R CMD check counts any `warning: unused` line as significant (*found at Stage 0*). `src/Makevars` therefore sets `STBIDEF`, `STBIWDEF` and `STBTT_DEF` to `extern`, which `$(C_VISIBILITY)` keeps hidden. `STBTT_DEF` needed the `#ifndef` guard of patch `0003`. External linkage keeps code the compiler would otherwise drop, and the HDR writer's `sprintf()` came with it; patch `0005` makes it `snprintf()`.
- **stdio and asserts.** The libraries write to no standard stream and call no `printf`, `puts`, `abort`, `exit` or `rand` (*read 2026-10-08*). `stb_image_write`'s HDR header uses `sprintf()`, which patch `0005` replaces. `fopen()`, `fread()` and `fwrite()` appear only in file entry points zusvg does not call (`plutosvg_document_load_from_file()`, `plutovg-font.c`'s file loader, `stb_image`'s and `stb_image_write`'s stdio paths). `snprintf()` appears in `plutovg-font.c`. `assert()` appears about fifteen times: `plutovg-blend.c`, `-font.c` (including `assert(false)`), `-ft-stroker.c` and `-path.c`, plus the `stb` headers' default `STBI_ASSERT` and `STBIW_ASSERT`. R's `-DNDEBUG` removes all of them in an installed build, and `load_all()`'s `-UNDEBUG` keeps them, which is why `tools/check-symbols` runs on an `R CMD INSTALL` build. The template's rule applies regardless. `tools/check-symbols` runs `nm -u` on the built objects and fails on:
  - `stdout`, `stderr` and the stream symbols clang rewrites `fprintf()` into (`fwrite` against `__stderrp`);
  - `printf`, `fprintf`, `fputs`, `puts`, `sprintf`, `vsprintf`;
  - `abort`, `exit`, `assert` (`__assert_fail`, `__assert_rtn`);
  - `rand` and the rest of the system RNG.

  It fails even where a symbol sits behind a path never taken, and any hit is removed by a recorded patch (D4), not justified.
- **FreeType hooks.** `plutosvg-ft.h` and `plutosvg_ft_svg_hooks()` are compiled without `PLUTOSVG_HAS_FREETYPE`, so they are an empty stub.

Vendoring follows zucbor §13 and the template: the two trees live byte-identical under `src/vendor/plutosvg/` and `src/vendor/plutovg/` at pinned tags, `tools/update-plutosvg` refreshes them, `tools/verify-vendor` compares them to the tags plus exactly the patches in `tools/patches/` (CI: `vendor.yaml`), and `src/vendor/PROVENANCE` records tags, commits, tarball checksums, the file lists and every patch with its reason. The `LICENSE` of each and plutovg's `FTL.TXT` are reproduced in `inst/COPYRIGHTS`, `LICENSE.note` records provenance, and `DESCRIPTION` says `License: MIT + file LICENSE` and `Copyright: file inst/COPYRIGHTS`, with both libraries' authors as `cph` in `Authors@R`, each with a `comment` naming the library, as zuhtml does for Gumbo.

---

## 10. Input sources

| Input | Handling |
|---|---|
| raw vector | copied into the document |
| character string | its bytes, after `enc2utf8()` |
| connection | read whole with `readBin()` in 64 KiB blocks up to `max_size + 1` (zucbor's `zu_read_bounded()`, `R/read.R`) |
| file (`svg_read()`) | read whole through `file()`, which decompresses gzip (`.svgz`) itself |

gzip needs no dependency (*decided at Stage 1*, D16). R's `file()` decompresses a `.svgz` file transparently. A raw vector or connection that starts with the gzip magic bytes is written to a temporary file and read back through `gzfile()`. `gzcon(rawConnection())` was the first choice, but valgrind showed R's own `do_gzcon()` reading uninitialised memory (R 4.6). Either way the bytes pass through the same bounded read, so `max_size` caps the decompressed size and a small compression bomb fails as `zusvg_limit_error`. Corrupt gzip fails as `zusvg_parse_error` with `offset = NA`. The RFC planned `zukomp::komp_decompress()` for this; zukomp is now needed only for PNG compression (§7).

---

## 11. Errors

| Class | When |
|---|---|
| `zusvg_invalid_argument` | a parameter, an unknown `as`, a bad colour |
| `zusvg_parse_error` | the pre-scan or the loader refused the document |
| `zusvg_encoding_error` | the input is not UTF-8 |
| `zusvg_limit_error` | a limit of §12; `limit`, `limit_value` fields |
| `zusvg_missing_element` | `id` is not in the document |
| `zusvg_render_error` | plutosvg's render returned `false` |
| `zusvg_memory_error` | a surface or buffer could not be allocated |
| `zusvg_io_error` | a file or connection could not be read or written |

Warnings: `zusvg_text_skipped` and `zusvg_clip_skipped` (§6.4). Every class inherits `zusvg_error` (or `zusvg_warning`); the parse error carries `offset` when the pre-scan found the fault and `NA` when the loader did, since the loader gives no position. Statuses come back from C by enumerator name and R raises (`zucbor`'s convention). Tests assert on class.

---

## 12. Limits and hostile input

| Limit | Default | Guards |
|---|---|---|
| `max_size` | 64 MiB | bytes read from any source |
| `max_elements` | 1e5 | start tags, so heap growth |
| `max_depth` | 256 | lexical nesting; `<use>` hops are bounded by D4's depth patch |
| `max_pixels` | 5e7 | `width * height` before the surface; at most just under 2^29 (§6.1) |
| `images` | `TRUE` | `FALSE` refuses `<image` before any decode |

An SVG that is small and valid can still be expensive: a 100 by 100 document rendered at `width = 30000` is a 3.6 GB surface, which `max_pixels` refuses; a `<use>` fan-out (a group that uses one symbol ten times, wrapped in a symbol that a group uses ten times, and so on) multiplies drawing work by ten per level while the document grows by a few lines, so twenty levels in a kilobyte draw 10^20 shapes. This is the "billion laughs" of SVG. No input limit catches it, and `R_CheckUserInterrupt()` cannot interrupt it mid-render, since plutosvg has no callback. §18 Q2 records that as the open hostile case; the fuzz job runs with a per-input timeout to find such documents and they go into the corpus as known slow inputs. Gradients and dash arrays are bounded by plutosvg itself (*read 2026-10-08*: `MAX_DASHES` 128, `MAX_STOPS` 64, `MAX_GRADIENT_DEPTH` 128 for `href` chains between gradients).

A limit is a positive whole number or `Inf` where that makes sense; anything else is `zusvg_invalid_argument`. Each guard in the pre-scan carries a `/* GUARD: name */` marker and `tools/run-mutation-check` proves it load-bearing, as in zucbor.

---

## 13. Memory model

The document's bytes and its plutosvg object live in one external pointer; the surface, canvas and output buffer of a render in another, created before any R allocation in the call and released by the normal path or the finalizer. No plutovg object is ever held in a static or across a `.Call`. The palette callback runs plutovg code, not R code: it looks names up in a C array prepared before rendering, so no R function runs mid-render and nothing can longjmp through plutovg's frames. That is a deliberate restriction: a `palette` function argument (§18) would need the handler pattern zucbor uses for tags.

---

## 14. Build, portability and CRAN

- `src/Makevars` lists the object files by hand: the 12 vendored ones (11 plutovg, `plutosvg.c`) plus the project's (`init.c` at Stage 0, then `zsg_scan.c` and `zsg_doc.c` at Stage 1 and `zsg_render.c` at Stage 2, 17 in all). Portable make only, no `Makevars.win`. `PKG_CFLAGS = $(C_VISIBILITY)`. `PKG_CPPFLAGS` holds:
  - `-Ivendor/plutovg/include -Ivendor/plutosvg/source`;
  - `-DPLUTOVG_BUILD_STATIC -DPLUTOSVG_BUILD_STATIC`, and never `-DPLUTOVG_BUILD` or `-DPLUTOSVG_BUILD`, which export the API (§4);
  - `-DSTBIDEF=extern -DSTBIWDEF=extern -DSTBTT_DEF=extern` (§9);
  - `-DPLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD`;
  - the `STBI_NO_*` list of §9 and `-DSTBI_NO_THREAD_LOCALS`.

  `PKG_LIBS = -lm`. `src/Makevars` gives the reason for each.
- `_WIN32` paths in `plutovg-font.c` include `windows.h` and use a `CRITICAL_SECTION` for the font cache's mutex; they compile under Rtools' MinGW and UCRT, and the cache is never used. The ASan, UBSan, valgrind, LTO, rchk and gctorture jobs run as in zucbor; the fuzz job builds the pre-scan and the loader under libFuzzer.
- R CMD check also reports any diagnostic-suppressing pragma in the sources. stb_truetype's `#pragma GCC diagnostic ignored "-Wcast-qual"` is removed by patch `0006`, since `-Wcast-qual` is in neither `-Wall` nor `-Wextra`.
- Compiler warnings from the vendored trees under `-Wall -Wextra -pedantic` are recorded in Stage 0 (`src/vendor/PROVENANCE`; under CRAN's `-Wall -pedantic`, clang and GCC now print none); any that CRAN's own flags would print are fixed by a recorded patch (D4), not by silencing, and never by a diagnostic-suppressing pragma, which draws its own NOTE.
- No system dependency: `SystemRequirements` is empty, which is the package's reason to exist.
- `LinkingTo: zufast (>= 0.1.0)`, with `Remotes: pedrobtz/zufast@main` during development only (R10.2). CRAN order (R10.5): after `zufast`, which on 2026-10-08 carries `Version: 0.1.0` but no tag and is not yet submitted. `zukomp` (submitted 2026-10-06, not yet accepted) must be on CRAN before Stage 6 adds it to `LinkingTo` and `Imports`. If it is not by then, PNG keeps `stb_image_write`'s deflate for 0.1.0.
- `Imports: grDevices` (`col2rgb()`, from Stage 2); `Suggests` names every package a test, example or vignette uses (`png`, `jpeg`, `grid`, `ggplot2`, `testthat`, `withr`, `knitr`, `rmarkdown`).
- Licence MIT with the vendored notices (§9); `Language: en-GB`; `.Rbuildignore` covers `.agents/`, `.claude/`, `tools/`, `fuzz/`.

---

## 15. Testing

- **Fixtures.** `tests/testthat/fixtures/` holds a project corpus of SVGs with pinned rendered hashes: each element type, each `preserveAspectRatio` value, gradients with each spread method and both unit systems, clip paths (pinning the warning, and the unclipped pixels until D15's patch), `use` of symbols and of elements, a long `<use>` chain (pinning D4's depth patch), nested svg, `currentColor` and `var()`, embedded PNG and JPEG, text (to pin the warning), `.svgz`, and the `resvg` test suite's `structure` and `painting` subsets that use only supported features (CC0, pulled by `tools/update-fixtures`, never by hand; `tests/testthat/fixtures/README.md` lists sources and licences).
- **Cross-check.** Where `rsvg` is installed, each supported fixture renders through both and the mean absolute channel difference is bounded (anti-aliasing and un-premultiply rounding differ; shapes must not); Stage 3 sets the bound from the fixtures and records it here. Fixtures whose clip changes pixels are excluded until D15's patch lands. This runs in the `conformance` job only, which installs `rsvg`: no test calls it, so it is not a dependency, and valgrind finds leaks inside librsvg (Stage 3).
- **Shape tests.** Each `as` value's class, dim and a few pinned pixels; `rasterGrob()` and `rasterImage()` draw the native output in a `png()` device, and the test reads the file back with `png::readPNG()` and compares pixels within a tolerance, since the device's bytes depend on its platform backend.
- **Pinned hashes on CRAN.** Exact render hashes are compared under `skip_on_cran()` and in the conformance job; the tests CRAN runs compare pinned pixels within one level per channel, so an FMA difference on a CRAN machine (§8) cannot fail the check.
- **Limits and faults.** Every class of §11 with a crafted input, the pre-scan's offsets, the loader's `NA` offset, each limit at its boundary.
- **Fuzzing.** `fuzz/fuzz_svg.c` loads and renders at 64 by 64 under libFuzzer with the project corpus seeded; invariants: no crash, no leak, every return path destroys its objects, a document the pre-scan accepts is either loaded or refused as `zusvg_parse_error`. `fuzz/fuzz_canary.c` must crash first.
- **Determinism.** The conformance job hashes every fixture's render on each runner and compares.
- **Memory.** gctorture and valgrind jobs as zucbor; a test that renders 1 000 documents checks that the process's resident size does not grow (finalizers run).
- Tests are self-sufficient, pass under `shuffle = TRUE`, stay serial, and the CRAN suite runs in under 15 s; the 1 000-document and large-surface cases call `skip_heavy()`.

---

## 16. Performance targets

Measured by `tools/run-benchmarks` against `rsvg` and `magick` where installed, on the project fixtures, and recorded here when Stage 6 runs them:

- Loading and rendering a 2 KB icon at 64 by 64: under 100 µs, which is the cost that matters for a sheet of a thousand icons.
- A 500 KB map at 2000 by 2000: within 3× of `rsvg`. plutovg is a scanline rasteriser without SIMD; parity is not the target.
- `nativeRaster` output adds no copy beyond the ARGB-to-ABGR pass; `"array"` costs the 8× expansion to doubles and is the slow path.

---

## 17. Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Library | plutosvg and plutovg, vendored; not nanosvg |
| D2 | Default output | `nativeRaster`; `as = "array"` for `rsvg` drop-in |
| D3 | Text | never; a document with text renders without it and warns once |
| D4 | Vendor trees | byte-identical plus a recorded patch set in `tools/patches/`, applied by `tools/update-plutosvg`, verified by `tools/verify-vendor`, sent upstream |
| D5 | Pre-scan | zusvg's own, mirroring plutosvg's tokenizer; not `zuxml` |
| D6 | Images | on by default; `STBI_NO_*` for everything but PNG and JPEG; `images = FALSE` for untrusted input |
| D7 | Both sizes given | stretch, as `rsvg` does; `svg_extents()` for fitting |
| D8 | Palette | a named character vector, not a function (§13) |
| D9 | Paths | `svg_read()` only; a character `x` elsewhere is always document text |
| D10 | Documenting the gaps | first paragraph of the package help page and `svg_elements()`'s `has_text` |
| D11 | Warnings | classed, one per rendering call (§6.4) |
| D12 | Licence fields | `MIT + file LICENSE`, `Copyright: file inst/COPYRIGHTS`, `cph` entries for both libraries, `inst/COPYRIGHTS` with the FTL text; zuhtml's precedent (*this document's reading of the RFC's §9, which said the same without the precedent*) |
| D13 | Internal prefix | `zsg_` / `ZSG_`, not the RFC's `zsv_` (§3; *read 2026-10-08*) |
| D14 | Exact hashes | checked in CI's conformance job and under `skip_on_cran()`; CRAN's tests use a one-level pixel tolerance (§15) |
| D15 | Clip paths | for 0.1.0, a `zusvg_clip_skipped` warning when a document references a clip path that is not a full-canvas rectangle, with `has_clip` in `svg_elements()`; a patch applying `clip-path`, offered upstream, after 0.1.0 (§3's survey; §18 Q8) |
| D16 | gzip input | decompressed with base R (`file()`, `gzfile()`) under the bounded read; no zukomp, and no `zusvg_unsupported_input` class (§10) |
| D17 | `<use>` of a `<symbol>` or `<svg>` | sized by the `<use>`'s `width` and `height` where given (SVG 1.1 §5.6), through patch `0008-use-symbol-size`, offered upstream (§9) |

Reasons where they are not in the section cited:

- **D1.** nanosvg is older, unmaintained since 2022 and single-header; plutosvg is maintained, used by FreeType for colour emoji, separates parser from rasteriser, and has `<use>`, `<symbol>` and the `var()` palette. Clip paths are not a reason for the choice: the RFC counted them in plutosvg's favour, but 0.0.8 does not apply them (*read 2026-10-08*; D15).
- **D2.** It is what R's graphics take and it is 8× smaller. `as = "array"` is one argument away for drop-in use.
- **D3.** Text needs fonts, fonts need a system font lookup or bundled fonts, and either breaks the no-dependency promise. The Stage 0 survey (§3) confirmed it: no icon in the four sets surveyed uses text.
- **D4.** The set after Stage 0, in `tools/patches/`:
  - `0001-use-depth`: `<use>` hops count against `MAX_RENDER_DEPTH`. This is required: 0.0.8's cap does not cover `<use>` chains (§9). `tools/check-use-chain` shows a 30 000-hop chain (about 1 MB) crashing without it.
  - `0002-loader-alloc-checks`: every plutosvg loader allocation is checked (§9 says what is left).
  - `0003-stbtt-def-guard`: `#ifndef STBTT_DEF`, so the build chooses its linkage (§9).
  - `0004-stroker-unused-point`: a variable GCC's `-Wall` reports as set but not used.
  - `0005-stbiw-snprintf`: the HDR writer's `sprintf()` (§9).
  - `0006-stbtt-no-pragmas`: the diagnostic-suppressing pragmas (§14).
  - `0007-bsearch-const`: in C23, `bsearch()` on a `const` table returns `const void *`, and the non-const result in `lookupid()` was a qualifier-discarding warning under R-devel's clang (found by the `clang23` CI leg).
  - `0008-use-symbol-size` (Stage 3): a `<use>`'s `width` and `height` size the `<symbol>` or `<svg>` it references (D17).
  - `0014-stbiw-jpg-unsigned-bits` (Stage 4): the JPEG writer's bit buffer shifted as unsigned. UBSan in CI flagged a signed left-shift overflow on every JPEG encoded.

  Expected later:
  - from Stage 6, the one-line `STBIW_ZLIB_COMPRESS` prototype (§7);
  - whatever §18 Q2 and Q9 decide;
  - after 0.1.0, D15's clip patch.

  A patch upstream accepts is dropped at the next pin.
- **D5.** plutosvg is not an XML parser (no entities, no namespaces, lax closing), so an XML parser's judgement would differ from the loader's in both directions.

---

## 18. Open questions

Each stays the maintainer's until recorded above; the recommendation is the RFC's unless marked otherwise.

1. Whether a `palette` function is worth the handler machinery of §13 for dynamic theming; the vector form covers the icon-set case. Recommended: no, until asked.
2. A render timeout or element budget for the `<use>` fan-out of §12: plutosvg has no callback, so it would be a patch (D4) adding a step counter and an abort flag, which upstream may or may not want. Stage 5's fuzzing decides whether it is needed before CRAN. Recommended since the 2026-10-08 reading: yes. The growth is exponential in a kilobyte of input, not quadratic as the RFC had it, so an untrusted-input package needs the bound. Stage 5 then decides only the budget's default.
3. `svg_document()` returning the parsed tree as an R list over `zuxml` for callers who want to inspect or edit, and `svg_write()` to emit it back: a different feature, likely a different package.
4. A cairo-free vector output through `zupdf` (RFC 0008): plutovg's path model maps onto PDF content streams, so SVG-to-PDF without rendering is possible once both packages exist.
5. Whether `svg_jpeg()` belongs at all; it is three lines over plutovg and `rsvg` has no equivalent. Recommended: keep it; the cost is nil and `background = "white"` makes it correct by default.
6. **The feature survey.** *Decided at Stage 0*: the results are in §3. D3 stands, and the audience is icons and logos, not R-generated plots, badges or diagrams.
7. **The name.** `zusvg` says "zu-family SVG" but the package rasterises rather than reads or writes the format as the others do; `zusvgr` or similar is for the maintainer. Renaming is free until the first tag.
8. **Clip paths.** *Decided at Stage 0*: D15. The survey (§3) found clipping alone visible in 0.01% of icons and about 1% of R-package SVGs, so the 0.1.0 answer is a warning, and the patch follows after 0.1.0. The warning skips full-canvas rectangles, which are 97% of the clips found and would make it noise.
9. **Floating-point contraction** (*from the 2026-10-08 reading*). If Stage 2 finds arm64 and x86-64 hashes differ (§8), the options are:
   - (a) A D4 patch adding `#pragma STDC FP_CONTRACT OFF` to the float-heavy plutovg files. Clang honours this pragma; GCC ignores it and would need its own per-function attribute.
   - (b) Withdrawing byte-identity across architectures from §8 and §19, and keeping it per architecture.

   Recommended: measure first. If they differ, (a) for clang and (b) for GCC.

10. **`<use>` width and height on a `<symbol>`.** *Decided at Stage 3*: patch `0008-use-symbol-size` (D17).

---

## 19. Acceptance criteria for v0.1.0

1. Installs from source on Linux, macOS (x86-64 and arm64) and Windows with no system package, under `R CMD check --as-cran` with no NOTE beyond the new-submission one.
2. Every fixture renders byte-identically on all CI runners, or per architecture if §18 Q9 chose (b).
3. Every supported fixture is within tolerance of `rsvg` in the conformance job.
4. No crash, leak or UB in 30 minutes of nightly fuzzing on the corpus, under ASan and UBSan; the canary has been seen to crash.
5. Every §11 class has a test; every §12 guard survives the mutation check.
6. A thousand 64 by 64 icon renders take under 0.1 s.
7. `tools/verify-vendor` passes against the pinned tags plus the recorded patches, and `tools/check-symbols` finds only the init symbol.

---

## 20. What this design does not decide

- The patch set's exact content, which the first build and the first fuzz run determine (D4).
- Whether `zukomp` is on CRAN in time for Stage 6; if not, the better PNG compression moves past 0.1.0 (§14).
- §18 Q7: the name.
- §18 Q9: whether floating-point contraction breaks byte-identity across architectures.
- Two values that later stages record here: the `rsvg` cross-check's bound (Stage 3, §15) and the benchmarks (Stage 6, §16).
