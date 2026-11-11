# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/native-code.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

`zusvg` is an R package that renders SVG documents to pixels
(`nativeRaster`, RGBA array, raw RGBA, PNG, JPEG) with **vendored copies of
plutosvg and plutovg**, two small MIT-licensed C libraries, so it installs
from source on every CRAN platform with no system library: no librsvg, no
cairo, no Rust toolchain. It renders whole documents or one element by `id`,
resolves `currentColor` and CSS `var()` colours from R, measures documents
and elements, validates untrusted input under limits, and produces
byte-identical output on every platform. Zero hard runtime dependencies
(`grDevices` aside; `zufast` is build-time only). It deliberately does not
render text, filters, masks, patterns, CSS stylesheets or external
references, and plutosvg 0.0.8 does not apply clip paths (design D15: a
warning in 0.1.0, a patch after). It never will render text (design D3):
documents with text render without it and warn once.

Two documents outrank this file. [.agents/design.md](.agents/design.md) is
the specification, numbered §1–§20: every statement in it is a decision, and
open questions live only in its §18. [.agents/roadmap.md](.agents/roadmap.md)
sequences it into Stages 0–7, each with a **Status:** line under its heading.
Both were adopted on 2026-10-08 from
[RFC 0007](https://github.com/pedrobtz/packages/blob/main/rfcs/0007-zusvg-svg-rasteriser.md)
in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap
sequences.

It is a member of the `zu*` family (sibling checkouts in `../`), the first
whose vendored library draws. `zucbor` and `zuhtml` are the models for
vendoring, `PROVENANCE`, the patch series, `verify-vendor` and
`check-symbols`; `zucbor` for the pre-scan's R-free shape, the `/* GUARD */`
mutation check and classed conditions.

## Current state

**2026-10-22: 0.1.0 is ready to submit once CI is green.** Stages 0–6 are
merged (#11, #15–#20), and Stage 7's preparation is too (#21): vignette,
README, pkgdown, `cran-comments.md`, `Version: 0.1.0`. zufast 0.1.0 reached
CRAN on 2026-10-21 and `Remotes:` is gone. The fuzz timeout (#27) is fixed by
patch 0017 (#29). On 2026-10-23 the NOSUGGESTS and NOLD check legs were
added (#30). Before submitting: a full green CI run on `main`. Stage 7 (#10)
stays open until CRAN accepts. Seventeen patches are applied to the vendored
libraries (`tools/patches/`). Design §16 records the benchmarks, and the
roadmap's Stage 7 table records the §19 acceptance criteria. zusvg is not on
CRAN (crandb, 2026-11-11).

Update this section at the end of every stage.

## Versions and dependents

The `v0.1.0` parent issue is #2; the roadmap has eight stages, 0 to 7, and
Stage 7 is #10. A deviation from a stage's exit criteria is recorded in its
**Status:** line first, and status never goes in a heading.

zusvg links to a sibling: `LinkingTo: zufast (>= 0.1.0)`, on CRAN since
2026-10-21, so there is no `Remotes:`. Design §14 planned `zukomp` in
`LinkingTo` and `Imports` from Stage 6, for PNG's zlib stream; it was not
taken up, and 0.1.0 keeps `stb_image_write`'s deflate (design §20). #31
proposes, for 0.2.0, encoding PNG and JPEG through `zupix` instead and
withdrawing the zukomp hook. Sibling packages that depend on zusvg: none.
The name itself is open until the first tag (design §18 Q7).

## Commands

The everyday `devtools` commands are in `.claude/shared/r-package.md`;
`load_all()` compiles both vendor trees. The check here runs in CRAN mode with
the clock check off:

```sh
_R_CHECK_SYSTEM_CLOCK_=0 Rscript -e 'devtools::check(cran = TRUE)'
```

zufast is on CRAN: `install.packages("zufast")`. roxygen2 must be 8.1.0 or
newer.

Gate scripts, with the roadmap stage that added each:

<!-- markdownlint-disable MD013 -->
```sh
tools/update-plutosvg <svg-tag> <vg-tag>   # Stage 0: re-vendor both trees, apply tools/patches/, write PROVENANCE
tools/verify-vendor [--canary]             # Stage 0: trees == tags + patches; PROVENANCE, zsg_vendor.h agree (CI: vendor)
tools/check-use-chain [hops]               # Stage 0: 0001-use-depth is load-bearing (CI: vendor)
R CMD INSTALL -l <lib> . && tools/check-symbols <lib>/zusvg/libs/zusvg.so
                                           # Stage 0: only R_init_zusvg exported; no stdio/sprintf/abort/exit/assert/rand
tools/update-fixtures                      # Stage 2: project corpus + resvg subsets + hashes.tsv
tools/run-fuzz [secs]                      # Stage 5: canary first, then fuzz_svg under ASan+UBSan (CI: hardening)
tools/run-lint                             # Stage 5: strict warnings on project C
tools/run-mutation-check                   # Stage 5: every pre-scan guard seen to be load-bearing
tools/check-no-network                     # Stage 5
tools/run-benchmarks                       # Stage 6: vs rsvg and magick where installed; not a gate
```
<!-- markdownlint-enable MD013 -->

Run `tools/check-symbols` on a `R CMD INSTALL --preclean` build, never a
`load_all()` one (`-UNDEBUG` keeps `assert()`s in). `--preclean` matters:
`R CMD INSTALL` reuses objects left in `src/vendor/` by `load_all()`.

## Architecture

Layout, from design §4, §9 and §14:

<!-- markdownlint-disable MD013 -->
```text
R/            load.R, read.R, validate.R, size.R, render.R, output.R (png, jpeg),
              elements.R, conditions.R, args.R, info.R,
              zu_source.R (copied verbatim from zuxml), the bounded read from zucbor's R/read.R,
              zusvg-package.R
src/          init.c                          registration only
              zsg_scan.h, zsg_scan.c          pre-scan: R-free; UTF-8, counts, limits, <text>/<image>
              zsg_doc.h, zsg_doc.c            document external pointer over plutosvg_document_t;
                                              zusvg_load() and its .Call siblings
              zsg_render.c                    surface, canvas, palette callback, ARGB -> ABGR/RGBA
              zsg_info.c, zusvg.h             zusvg_info() and its self-test render
              zsg_vendor.h                    pinned tags, commits, patch ids; written by tools/update-plutosvg
              Makevars                        hand-listed objects (12 vendored + project); *_BUILD_STATIC; stb flags; -lm
              vendor/plutosvg/, vendor/plutovg/   byte-identical at pinned tags, plus tools/patches/
              vendor/PROVENANCE
tools/        update-plutosvg, verify-vendor, check-symbols, check-use-chain, patches/,
              plutosvg-files.txt, plutovg-files.txt, vendor-warnings.txt, fuzz-env, gate scripts
fuzz/         fuzz_svg.c, fuzz_canary.c, probe.c (the pre-scan from the command line,
              for run-mutation-check), svg.dict (not in the tarball)
tests/testthat/fixtures/   project corpus, resvg subsets, hashes.tsv, README.md (sources, licences)
inst/COPYRIGHTS, LICENSE.note
.agents/      design.md, roadmap.md
```
<!-- markdownlint-enable MD013 -->

The pipeline is: read and decode the input in R → **pre-scan** (`zsg_scan.c`,
pure C, R-free: UTF-8, element and depth counts, `<image`/`<text` detection,
the limits; refuses with an offset before plutosvg sees a byte) →
**document** (`plutosvg_document_load_from_data()` over a copy of the bytes
owned by a finalized external pointer) → **render** (`plutovg_surface_t` and
canvas in a second external pointer; `plutosvg_document_render()` with
`current_color` and the palette callback; conversion to the requested R
object) → R value or encoded bytes. Only `zsg_doc.c`, `zsg_render.c` and
`zsg_info.c` include plutosvg or plutovg headers.

gzip input (`.svgz`) is decompressed with base R (`file()`, `gzfile()`)
under the bounded read, with no zukomp (design D16).

## Invariants that are easy to break

- **The vendor trees are upstream plus exactly the patch series.**
  `tools/verify-vendor` re-derives `src/vendor/` from the pinned tarballs and
  `tools/patches/`; any other edit fails it. Each patch is minimal, named in
  `PROVENANCE`, listed in `zusvg_info()` and asserted by `test-info.R`, and
  sent upstream. Never edit a vendored file in place.
- **CRAN's compiled-code check applies to vendored code too.** The list here
  is longer than the shared one: no `stdout`, `stderr`, `printf`, `fprintf`,
  `fputs`, `puts`, `sprintf`, `vsprintf`, `abort`, `exit`, `assert` or system
  RNG may be linked, even behind a path never taken or a `DEBUG` switch.
  zuxml's first upload was rejected at the pretest for justifying one.
  `tools/check-symbols` lists stream symbols as well as functions: clang
  rewrites `fprintf(stderr, ...)` into `fwrite`, and the symbol that exposes
  it is `__stderrp`.
- **The pre-scan contains no R** and mirrors plutosvg's tokenizer, not an XML
  parser's (design D5): `<`, `>`, `/>`, comments, CDATA, DOCTYPE, no
  entities. What it counts must be what the loader builds; if plutosvg's
  loader changes at a re-vendor, re-read it.
- **plutosvg keeps pointers into the input buffer for the document's life**,
  so the document owns a copy of the bytes, never the raw vector itself.
- **No R code runs mid-render.** The palette callback reads a C array
  prepared before `plutosvg_document_render()`; an R function there would
  longjmp through plutovg's frames and leak the surface. A `palette` function
  argument needs zucbor's handler pattern first (design §13, §18 Q1).
- **Every plutovg object made in a call is destroyed on both paths**: the
  normal return and the external pointer's finalizer. Nothing plutovg
  allocates is ever static or held across a `.Call`.
- **`max_pixels` and plutovg's 32768 dimension limit are checked before the
  surface is allocated**; a 100 by 100 icon at `width = 30000` must fail with
  `zusvg_limit_error`, not with a 3.6 GB `malloc()`.
- **R's `nativeRaster` is not premultiplied; plutovg's surface is.** Convert
  through straight RGBA (`plutovg_convert_argb_to_rgba()`) and then pack
  ABGR; packing ARGB directly gives wrong colours at partial alpha. The
  pinned pixel tests catch it.
- **`as = "array"` is `height x width x 4` and `as = "raw"` is
  `dim = c(4, width, height)`**, the exact shapes `rsvg::rsvg()` and
  `rsvg::rsvg_raw()` return; drop-in use depends on them.
- **Renders are byte-identical across platforms** (design §8). If a hash
  differs on one runner, find the cause or amend §8 in the same commit; never
  mark the test flaky. Exact hashes run under `skip_on_cran()` and in the
  conformance job; CRAN-run tests compare pixels within one level (D14),
  because floating-point contraction can differ on CRAN's machines.
- **The stb APIs have external, hidden linkage** (`-DSTBIDEF=extern` and
  friends, patch 0003): as plutovg's static functions, the unused ones are
  `-Wunused-function` under CRAN's `-Wall`, which R CMD check calls
  significant. External linkage keeps their code, so anything they call is
  linked: `tools/check-symbols` is what notices (it found `sprintf`, patch
  0005). `STBI_NO_THREAD_LOCALS` stays set: emulated TLS links libgcc's
  `abort()`.
- **Never define `PLUTOVG_BUILD` or `PLUTOSVG_BUILD`.** Without
  `*_BUILD_STATIC` they mark the whole vendored API `visibility("default")`,
  past `$(C_VISIBILITY)` (design §4).
- **Pixel sizes are checked in R as doubles before C sees them**: finite,
  under 32768, within `max_pixels`, and `max_pixels` below 2^29, because
  plutovg's `memset(height * stride)` is an `int` product and `(int)ceilf()`
  of a huge size is undefined (design §6.1).
- **`svg_read()` is the only function that takes a path.** A character `x`
  anywhere else is document text (D9).
- **The `STBI_NO_*` set and `images = FALSE`** are the defence against
  `stb_image`'s decoder CVEs; do not widen the compiled-in formats without a
  design decision.
- **Portable make only** in `src/Makevars`: hand-listed objects, no
  `$(wildcard)`, no `$(shell)`, no `-W*` overrides, no `Makevars.win`.
- **C never calls `Rf_error()`**; statuses by enumerator name,
  `R/conditions.R` raises.

## Naming

<!-- markdownlint-disable MD013 -->
| Layer | Prefix | Examples |
| --- | --- | --- |
| R exports | `svg_` plus `zusvg_info()` | `svg_load()`, `svg_render()`, `svg_png()` |
| R classes | `svg_` | `svg_document` |
| R condition classes | `zusvg_` | `zusvg_error`, `zusvg_parse_error`, `zusvg_text_skipped` (warning) |
| R and C internals | `zsg_` / `ZSG_` | `zsg_scan()`, `ZSG_STANDALONE` |
| `.Call` entry points | `zusvg_` | `zusvg_render` |
| Test-switching variables | `ZUSVG_` | `ZUSVG_SKIP_HEAVY`, `ZUSVG_SLOW_TESTS` |
<!-- markdownlint-enable MD013 -->

The internal prefix is `zsg_`, not the RFC's `zsv_`, because zucsv vendors
the zsv library, which defines `zsv_*` identifiers (design §3).

## Editing rules

These add to `.claude/shared/r-package.md`, or depart from it where stated.

- **No `README.Rmd`, unlike the shared rule**: edit `README.md` directly and
  run its example.
- Prose is en-GB (`Language: en-GB`, `inst/WORDLIST`). The package help
  page's first paragraph names what zusvg does not render (D10); keep it
  there.
- Hard runtime dependencies: none beyond `grDevices`, which is in `Imports`
  for `col2rgb()`. `png`, `jpeg`, `grid`, `ggplot2` stay in `Suggests`. A new
  one needs a recorded decision.
- Every export has `@return` and runnable `@examples`.
- `R/zu_source.R` is copied verbatim from `../zuxml`; fix it there and
  re-copy. The bounded read comes from zucbor's `zu_read_bounded()`
  (`../zucbor/R/read.R`), since zuxml's `zu_read_all()` has no limit.
- `NEWS.md` keeps a versioned heading.
- Branches for stages are `stage-N-<slug>`. Performance claims need evidence
  from `tools/run-benchmarks`. A defect in plutosvg or plutovg, or in
  `zufast`, gets an issue upstream; a plutosvg or plutovg fix also becomes a
  patch in `tools/patches/` until upstream releases it.

## Testing

- **Inputs** are built inside each `test_that()` (`svg_text()` in
  `helper-svg.R` wraps a body in a minimal document) or read from
  `fixtures/`. Files live under `withr::local_tempdir()`; devices are opened
  and closed inside the test.
- **Assert on condition classes and fields (`offset`, `limit`,
  `limit_value`)**, never message text.
- The suite runs serially: no `Config/testthat/parallel`.
- **The conformance oracle** is two things: the pinned render hashes in
  `fixtures/hashes.tsv`, checked on every platform, and `rsvg` where
  installed, within a mean-difference bound Stage 3 set (anti-aliasing
  differs; shapes must not), in the `conformance` job only. The `resvg` test
  suite's `structure` and `painting` subsets (CC0) are fetched by
  `tools/update-fixtures`, never by hand; `fixtures/README.md` lists every
  source and licence. Neither oracle covers text, filters or CSS, which the
  package does not render.
- **Helpers**: `helper-svg.R` (`svg_text()`, `fixture()`,
  `fixture_hashes()`, the small documents `icon()`, `two_px()`, `sheet()`,
  and `gzip_bytes()`), `helper-render.R` (`render_hash()`, the md5 of a
  render's pixels packed little-endian; `render_rgba()`, `render_pixel()`,
  `expect_pixel()`), `helper-expect.R` (`expect_zusvg_error()`),
  `helper-skip.R` (`skip_heavy()` on `ZUSVG_SKIP_HEAVY`,
  `skip_if_no_slow_tests()` on `ZUSVG_SLOW_TESTS`, `rss_kb()`,
  `expect_flat_rss()`, `running_under_valgrind()`, `expect_quick()`);
  testthat's own `skip_if_not_installed("rsvg")`.
- **Fixtures are data**: `hashes.tsv` is read with `colClasses = "character"`
  and regenerated only by `tools/update-fixtures --record`, after
  understanding the change.
- **CRAN time budget: under 15 s.** The 1 000-document memory test and large
  surfaces call `skip_heavy()`.

## Definition of done

In addition to the shared definition: `gctorture(TRUE)` clean when C
changed, and CI green including `vendor.yaml`. A change to a contract (the
exports, the output shapes, the limits, the patch series) amends the design
in the same commit. A stage is done when its exit criteria pass in CI on all
three platforms; a gate counts once it has been seen to fail.

## Releasing to CRAN

The shared release steps apply. What is specific to zusvg: entering
`Pre-flight` also needed zufast on CRAN with `Remotes:` removed, and the
submission waits for a full green CI run on `main`.

## Continuous integration

Every r-actions call is pinned by commit (v1.22.0), as Stage 0 set (R5).

- `R-CMD-check.yaml` (`r-cmd-check.yml`). **A deviation from `ci.md`:** it
  runs quick on pull requests and full on every push to `main` and under
  `full-ci`, not `profile: auto`. The full profile adds the NOSUGGESTS and
  NOLD legs (#30).
- `coverage.yaml` (`coverage.yml`).
- `vendor.yaml` (`vendor.yml`): `tools/verify-vendor` and
  `tools/check-symbols` on every push, so an upstream bump cannot bring a
  forbidden symbol back.
- `vendor-upstream.yaml` (`vendor-upstream.yml`, one job per library),
  weekly on Mondays: a new upstream tag opens an issue.
- `native-checks.yaml`: sanitizers (UBSan, ASan with `-UNDEBUG`), valgrind,
  LTO, gctorture and blocking rchk; sanitizers and valgrind follow the same
  quick/full rule as R-CMD-check, and gctorture is quick on every pull
  request.
- `hardening.yaml`, the package's own: lint, mutation check, no-network, and
  fuzz with a per-input timeout, 120 s per push and 30 minutes nightly.
- `conformance.yaml`, the package's own, also weekly on Mondays:
  cross-platform hashes, the `rsvg` cross-check, benchmarks (informational).
- `pkgdown.yaml` uses r-lib's actions directly.

Dependabot updates the GitHub Actions. Every stage touches `src/`, so stage
pull requests carry `full-ci`, a deviation from the shared quick-by-default
rule that the roadmap sets.

## Vendored native code

plutosvg (MIT) pinned at **v0.0.8** and plutovg (MIT, with FreeType Licence
parts for `ft-raster` and `ft-stroker`) pinned at **v1.3.3**, both
upstream's latest releases on 2026-10-08, in `src/vendor/plutosvg/` and
`src/vendor/plutovg/` with provenance in `src/vendor/PROVENANCE`. Re-vendor
with `tools/update-plutosvg`, never by hand. The rules are in
`.claude/shared/native-code.md`; what follows is zusvg's.

- Re-check upstream for a newer tag and for security advisories before
  every pin.
- `PROVENANCE` records the tags, the commits, the tarball checksums, the file
  lists, every patch with its reason, and the compiler warnings seen; keep
  `tools/update-plutosvg` mechanical. Compiler warnings seen are recorded in
  `tools/vendor-warnings.txt`, which `tools/update-plutosvg` copies into
  `PROVENANCE`.
- Keep plutovg's `FTL.TXT` in the vendor tree beside each `LICENSE`; declare
  every copyright holder found in the vendored file headers as `cph` in
  `Authors@R`; keep `inst/COPYRIGHTS` and `LICENSE.note` current;
  `License: MIT + file LICENSE` with `Copyright: file inst/COPYRIGHTS`
  (zuhtml's and data.sketches' CRAN precedent).
- Only the sources, headers and licence files are vendored: no tests,
  examples, Meson or CMake files, no FreeType integration
  (`PLUTOSVG_HAS_FREETYPE` undefined), no `HAVE_THREADS_H`.
- Compile with `-DPLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD`; never set
  `STBI_NO_STDIO`, which breaks `plutovg-surface.c`.
- The patch set (design D4, `tools/patches/`), seventeen patches:
  - planned: `0001-use-depth` (`<use>` hops count against the render depth;
    `tools/check-use-chain` proves it), `0002-loader-alloc-checks`
    (plutosvg's loader allocations; plutovg's growth arrays are not
    covered);
  - demanded by R CMD check: `0003-stbtt-def-guard`,
    `0004-stroker-unused-point`, `0005-stbiw-snprintf`,
    `0006-stbtt-no-pragmas`, `0007-bsearch-const` (C23 only);
  - for `<use>` of a `<symbol>`: `0008-use-symbol-size`;
  - for undefined behaviour, unbounded work and a hang that the fuzzer and
    the sanitizers found: `0009-render-step-budget`, `0010-ft-coord-clamp`,
    `0011-stbi-idct-wide`, `0012-dash-budget`,
    `0013-stroker-empty-border`, `0014-stbiw-jpg-unsigned-bits`,
    `0015-use-ancestor-cycle`, `0016-blend-defined-casts`,
    `0017-render-dash-budget` (one dash budget per render, the fuzz
    timeout of #27).

  `PROVENANCE` gives each one's reason.
