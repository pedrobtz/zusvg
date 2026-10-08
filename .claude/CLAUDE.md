# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`zusvg` is an R package that renders SVG documents to pixels (`nativeRaster`, RGBA array, raw RGBA, PNG, JPEG) with **vendored copies of plutosvg and plutovg**, two small MIT-licensed C libraries, so it installs from source on every CRAN platform with no system library: no librsvg, no cairo, no Rust toolchain. It renders whole documents or one element by `id`, resolves `currentColor` and CSS `var()` colours from R, measures documents and elements, validates untrusted input under limits, and produces byte-identical output on every platform. Zero hard runtime dependencies at first (`zufast` is build-time only); `zukomp` joins `LinkingTo` and `Imports` at Stage 6 for `.svgz` and PNG compression if it is on CRAN by then. It deliberately does not render text, filters, masks, patterns, CSS stylesheets or external references, and plutosvg 0.0.8 does not apply clip paths (design D15: a warning in 0.1.0, a patch after), and never will render text (design D3): documents with text render without it and warn once.

Two documents outrank this file. [.agents/design.md](../.agents/design.md) is the specification, numbered §1–§20: every statement in it is a decision, and open questions live only in its §18. [.agents/roadmap.md](../.agents/roadmap.md) sequences it into Stages 0–7, each with a **Status:** line under its heading. Both were adopted on 2026-10-08 from [RFC 0007](https://github.com/pedrobtz/packages/blob/main/rfcs/0007-zusvg-svg-rasteriser.md) in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap sequences.

It is a member of the `zu*` family (sibling checkouts in `../`), the first whose vendored library draws. `zucbor` and `zuhtml` are the models for vendoring, `PROVENANCE`, the patch series, `verify-vendor` and `check-symbols`; `zucbor` for the pre-scan's R-free shape, the `/* GUARD */` mutation check and classed conditions.

## Current state

**2026-10-08: Stage 0 is in review.** Its pull request delivers the following, and every other export arrives from Stage 1:
- plutosvg 0.0.8 and plutovg 1.3.3, vendored with six patches;
- `tools/update-plutosvg`, `verify-vendor`, `check-symbols` and `check-use-chain`;
- `zusvg_info()`;
- `vendor.yaml` and `vendor-upstream.yaml`.

`devtools::check(cran = TRUE)` is 0/0/0 on macOS arm64, and both clang and GCC 16 build the vendored code with no warning under CRAN's `-Wall -pedantic`. The feature survey is in design §3: the audience is icons and logos, and clip paths warn for 0.1.0 (D15). Tracking: parent #2, stages #3–#10.

Update this paragraph at the end of every stage.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, `v0.1.0`. Not yet opened (2026-10-08); Stage 0 opens it and `.github/scripts/stage-cards.sh` in `pedrobtz/packages` puts it on the board.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for example `Stage 2 — svg_render() with as = "native"; shape tests; fixtures`, linking to that section's anchor. The roadmap has eight stages, 0 to 7.
- **Every tracking issue carries the `stage` label.**
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the body. Never close a stage whose exit criteria are not met; record a deviation in its **Status:** line first.
- **The roadmap stays authoritative.** Adding, removing or renaming a stage means editing the roadmap and the sub-issues in the same change. Status never goes in a heading.
- Close the parent issue when CRAN accepts the version and it is tagged.

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the package enters `Pre-flight` (Stage 7). Bump to `0.1.0.9000` only after CRAN accepts it.

Until the first release the R API may change freely. zusvg depends on a sibling before CRAN does: `LinkingTo: zufast (>= 0.1.0)` from `Remotes: pedrobtz/zufast@main` during development. **zufast must be on CRAN before zusvg is submitted** (R10.5); on 2026-10-08 it is untagged and unsubmitted. `Remotes:` goes at Stage 7. `zukomp` (submitted 2026-10-06) is added to `LinkingTo` and `Imports` only when it is on CRAN. No package depends on zusvg. The name itself is open until the first tag (design §18 Q7).

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ (both vendor trees) and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
_R_CHECK_SYSTEM_CLOCK_=0 Rscript -e 'devtools::check(cran = TRUE)'
air format .                                     # format R sources
```

zufast is not on CRAN: install it from `../zufast` or `pak::pak("pedrobtz/zufast")`. roxygen2 must be 8.1.0 or newer.

Gate scripts, each arriving at the roadmap stage named:

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

Run `tools/check-symbols` on a `R CMD INSTALL --preclean` build, never a `load_all()` one (`-UNDEBUG` keeps `assert()`s in). `--preclean` matters: `R CMD INSTALL` reuses objects left in `src/vendor/` by `load_all()`.

## Architecture

Planned layout, from design §4, §9 and §14. Nothing under `src/` beyond the template exists yet.

```text
R/            load.R, read.R, validate.R, size.R, render.R, output.R (png, jpeg),
              elements.R, colours.R, conditions.R, args.R, info.R,
              zu_source.R (copied verbatim from zuxml), the bounded read from zucbor's R/read.R,
              zusvg-package.R
src/          init.c                          registration only
              zsg_scan.h, zsg_scan.c          pre-scan: R-free; UTF-8, counts, limits, <text>/<image>
              zsg_doc.c                       document external pointer over plutosvg_document_t
              zsg_render.c                    surface, canvas, palette callback, ARGB -> ABGR/RGBA
              zsg_r.c                         .Call glue; statuses by name
              zsg_info.c, zusvg.h             zusvg_info() and its self-test render
              zsg_vendor.h                    pinned tags, commits, patch ids; written by tools/update-plutosvg
              Makevars                        hand-listed objects (12 vendored + project); *_BUILD_STATIC; stb flags; -lm
              vendor/plutosvg/, vendor/plutovg/   byte-identical at pinned tags, plus tools/patches/
              vendor/PROVENANCE
tools/        update-plutosvg, verify-vendor, check-symbols, patches/, file lists, gate scripts
fuzz/         fuzz_svg.c, fuzz_canary.c (not in the tarball)
tests/testthat/fixtures/   project corpus, resvg subsets, hashes.tsv, README.md (sources, licences)
inst/COPYRIGHTS, LICENSE.note
.agents/      design.md, roadmap.md
```

The pipeline is: read and decode the input in R → **pre-scan** (`zsg_scan.c`, pure C, R-free: UTF-8, element and depth counts, `<image`/`<text` detection, the limits; refuses with an offset before plutosvg sees a byte) → **document** (`plutosvg_document_load_from_data()` over a copy of the bytes owned by a finalized external pointer) → **render** (`plutovg_surface_t` and canvas in a second external pointer; `plutosvg_document_render()` with `current_color` and the palette callback; conversion to the requested R object) → R value or encoded bytes. Only `zsg_doc.c` and `zsg_render.c` include plutosvg or plutovg headers.

## Invariants that are easy to break

- **The vendor trees are upstream plus exactly the patch series.** `tools/verify-vendor` re-derives `src/vendor/` from the pinned tarballs and `tools/patches/`; any other edit fails it. Each patch is minimal, named in `PROVENANCE`, listed in `zusvg_info()` and asserted by `test-info.R`, and sent upstream. Never edit a vendored file in place.
- **CRAN's compiled-code check applies to vendored code too.** No `stdout`, `stderr`, `printf`, `fprintf`, `fputs`, `puts`, `sprintf`, `vsprintf`, `abort`, `exit`, `assert` or system RNG may be linked, even behind a path never taken or a `DEBUG` switch. Remove with a patch, never justify in `cran-comments.md` (zuxml's first upload was rejected at the pretest for that), and never with a diagnostic-suppressing pragma. `tools/check-symbols` lists stream symbols as well as functions: clang rewrites `fprintf(stderr, ...)` into `fwrite`, and the symbol that exposes it is `__stderrp`.
- **The pre-scan contains no R** and mirrors plutosvg's tokenizer, not an XML parser's (design D5): `<`, `>`, `/>`, comments, CDATA, DOCTYPE, no entities. What it counts must be what the loader builds; if plutosvg's loader changes at a re-vendor, re-read it.
- **plutosvg keeps pointers into the input buffer for the document's life**, so the document owns a copy of the bytes, never the raw vector itself.
- **No R code runs mid-render.** The palette callback reads a C array prepared before `plutosvg_document_render()`; an R function there would longjmp through plutovg's frames and leak the surface. A `palette` function argument needs zucbor's handler pattern first (design §13, §18 Q1).
- **Every plutovg object made in a call is destroyed on both paths**: the normal return and the external pointer's finalizer. Nothing plutovg allocates is ever static or held across a `.Call`.
- **`max_pixels` and plutovg's 32768 dimension limit are checked before the surface is allocated**; a 100 by 100 icon at `width = 30000` must fail with `zusvg_limit_error`, not with a 3.6 GB `malloc()`.
- **R's `nativeRaster` is not premultiplied; plutovg's surface is.** Convert through straight RGBA (`plutovg_convert_argb_to_rgba()`) and then pack ABGR; packing ARGB directly gives wrong colours at partial alpha. The pinned pixel tests catch it.
- **`as = "array"` is `height x width x 4` and `as = "raw"` is `dim = c(4, width, height)`**, the exact shapes `rsvg::rsvg()` and `rsvg::rsvg_raw()` return; drop-in use depends on them.
- **Renders are byte-identical across platforms** (design §8). If a hash differs on one runner, find the cause or amend §8 in the same commit; never mark the test flaky. Exact hashes run under `skip_on_cran()` and in the conformance job; CRAN-run tests compare pixels within one level (D14), because floating-point contraction can differ on CRAN's machines.
- **The stb APIs have external, hidden linkage** (`-DSTBIDEF=extern` and friends, patch 0003): as plutovg's static functions, the unused ones are `-Wunused-function` under CRAN's `-Wall`, which R CMD check calls significant. External linkage keeps their code, so anything they call is linked: `tools/check-symbols` is what notices (it found `sprintf`, patch 0005). `STBI_NO_THREAD_LOCALS` stays set: emulated TLS links libgcc's `abort()`.
- **Never define `PLUTOVG_BUILD` or `PLUTOSVG_BUILD`.** Without `*_BUILD_STATIC` they mark the whole vendored API `visibility("default")`, past `$(C_VISIBILITY)` (design §4).
- **Pixel sizes are checked in R as doubles before C sees them**: finite, under 32768, within `max_pixels`, and `max_pixels` below 2^29, because plutovg's `memset(height * stride)` is an `int` product and `(int)ceilf()` of a huge size is undefined (design §6.1).
- **`svg_read()` is the only function that takes a path.** A character `x` anywhere else is document text (D9).
- **The `STBI_NO_*` set and `images = FALSE`** are the defence against `stb_image`'s decoder CVEs; do not widen the compiled-in formats without a design decision.
- **Portable make only** in `src/Makevars`: hand-listed objects, no `$(wildcard)`, no `$(shell)`, no `-W*` overrides, no `Makevars.win`.
- **C never calls `Rf_error()`**; statuses by enumerator name, `R/conditions.R` raises.

## Naming

| Layer | Prefix | Examples |
|---|---|---|
| R exports | `svg_` plus `zusvg_info()` | `svg_load()`, `svg_render()`, `svg_png()` |
| R classes | `svg_` | `svg_document` |
| R condition classes | `zusvg_` | `zusvg_error`, `zusvg_parse_error`, `zusvg_text_skipped` (warning) |
| R and C internals | `zsg_` / `ZSG_` | `zsg_scan()`, `ZSG_STANDALONE` |
| `.Call` entry points | `zusvg_` | `zusvg_render` |
| Test-switching variables | `ZUSVG_` | `ZUSVG_SKIP_HEAVY`, `ZUSVG_SLOW_TESTS` |

## Testing conventions

- **Self-sufficient.** Inputs built inside each `test_that()` (`svg_text()` in `helper-svg.R` wraps a body in a minimal document) or read from `fixtures/`. No file-scope objects; shared code in `helper-*.R`.
- **Self-contained.** Files under `withr::local_tempdir()`; devices opened and closed inside the test.
- **Assert on condition classes and fields (`offset`, `limit`, `limit_value`), never message text.**
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the definition of done; serial, no `Config/testthat/parallel`.
- **The conformance oracle** is two things: the pinned render hashes in `fixtures/hashes.tsv`, checked on every platform, and `rsvg` where installed, within a mean-difference bound Stage 3 sets (anti-aliasing differs; shapes must not), in the `conformance` job only. The `resvg` test suite's `structure` and `painting` subsets (CC0) are fetched by `tools/update-fixtures`, never by hand; `fixtures/README.md` lists every source and licence. Neither oracle covers text, filters or CSS, which the package does not render.
- **Helpers in `tests/testthat/helper-*.R`**: `helper-svg.R` (`svg_text()`, `fixture()`), `helper-expect.R` (`expect_zusvg_error()`, `expect_render_hash()`, `expect_pixel()`), `helper-skip.R` (`skip_heavy()` on `ZUSVG_SKIP_HEAVY`, `skip_if_no_slow_tests()` on `ZUSVG_SLOW_TESTS`, `skip_if_not_installed("rsvg")`).
- **Fixtures are data**: `hashes.tsv` is read with `colClasses = "character"` and regenerated only by `tools/update-fixtures --record`, after understanding the change.
- **Keep the suite inside the CRAN time budget:** under 15 s; the 1 000-document memory test and large surfaces call `skip_heavy()`.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0 warnings and 0 notes. The one allowed note is "New submission" before the first release. `devtools::test(shuffle = TRUE)` green. `gctorture(TRUE)` clean when C changed. CI green on every leg, including `vendor.yaml`. A user-facing change also needs a test, roxygen documentation and a `NEWS.md` entry. A change to a contract (the exports, the output shapes, the limits, the patch series) amends the design in the same commit. A stage is done when its exit criteria pass in CI on all three platforms; a gate counts once it has been seen to fail.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs `--as-cran` on the CRAN-like runners and containers, and replaces win-builder, the macOS builder and R-hub. `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** Stages 0–6 done, `Version: 0.1.0` with the `NEWS.md` heading, `cran-comments.md` written, CI green, zufast on CRAN and `Remotes:` removed.
- **Before submitting,** run the `cran-extrachecks` and `review-cran-submission` skills and resolve every finding.
- **The pretest is automated and does not read `cran-comments.md`.** Fix every NOTE, as under Vendored native code.
- **After acceptance,** tag `v0.1.0`, publish the GitHub release, bump to `0.1.0.9000`, close the parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- There is no `README.Rmd`; edit `README.md` directly and run its example.
- Prose is simple, short and en-GB (`Language: en-GB`, `inst/WORDLIST`). The package help page's first paragraph names what zusvg does not render (D10); keep it there.
- Wrap roxygen at 80 characters; `air format .` on R sources.
- `lower_snake_case`; the naming table above.
- Hard runtime dependencies: none until Stage 6 adds `zukomp` by recorded decision. `grDevices` is in `Imports` for `col2rgb()`; `rsvg`, `png`, `jpeg`, `grid`, `ggplot2` stay in `Suggests`.
- Every export has `@return` and runnable `@examples`; no roxygen topics for internals.
- `R/zu_source.R` is copied verbatim from `../zuxml`; fix it there and re-copy. The bounded read comes from zucbor's `zu_read_bounded()` (`../zucbor/R/read.R`), since zuxml's `zu_read_all()` has no limit.
- `NEWS.md` keeps a versioned heading.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. The scaffold's `R-CMD-check.yaml` (quick on pull requests, full on `main` and under `full-ci`) and `coverage.yaml` call it at `@v1`; `pkgdown.yaml` uses r-lib's actions directly, since r-actions has no pkgdown workflow. Stage 0 pins every r-actions call by commit (R5), adds Dependabot, and adds `vendor.yaml` (verify-vendor and symbols) and `vendor-upstream.yaml` (a new upstream tag opens an issue). The roadmap's CI table says which stage adds `native-checks.yaml` (UBSan, ASan with `-UNDEBUG`, valgrind, LTO, gctorture, blocking rchk), `hardening.yaml` (fuzz with a per-input timeout, lint, mutation check, no-network) and `conformance.yaml` (cross-platform hashes, `rsvg` cross-check, benchmarks). Every stage touches `src/`, so stage pull requests carry `full-ci`.

This file lives in `.claude/`, not the package root, because pkgdown renders every root-level `*.md` as a site page (alignment rule R8 in `pedrobtz/packages`); keep it here.

## Vendored native code

plutosvg (MIT) pinned at **v0.0.8** and plutovg (MIT, with FreeType Licence parts for `ft-raster` and `ft-stroker`) pinned at **v1.3.3**, both upstream's latest releases on 2026-10-08, in `src/vendor/plutosvg/` and `src/vendor/plutovg/` with provenance in `src/vendor/PROVENANCE`. Re-vendor with `tools/update-plutosvg`, never by hand.

- Pin a stable upstream release, never `master` or a release candidate; re-check upstream for a newer tag and for security advisories before every pin.
- Record the tags, the commits, the tarball checksums, the file lists, every patch with its reason, and the compiler warnings seen, in `PROVENANCE`; keep `tools/update-plutosvg` mechanical.
- Keep each library's `LICENSE` and plutovg's `FTL.TXT` in the vendor tree; declare every copyright holder found in the vendored file headers as `cph` in `Authors@R`; keep `inst/COPYRIGHTS` and `LICENSE.note` current; `License: MIT + file LICENSE` with `Copyright: file inst/COPYRIGHTS` (zuhtml's and data.sketches' CRAN precedent).
- Only the sources, headers and licence files are vendored: no tests, examples, Meson or CMake files, no FreeType integration (`PLUTOSVG_HAS_FREETYPE` undefined), no `HAVE_THREADS_H`.
- The patch set (design D4, `tools/patches/`): `0001-use-depth` (`<use>` hops count against the render depth; `tools/check-use-chain` proves it), `0002-loader-alloc-checks` (plutosvg's loader allocations; plutovg's growth arrays are not covered), and four that R CMD check demanded: `0003-stbtt-def-guard`, `0004-stroker-unused-point`, `0005-stbiw-snprintf`, `0006-stbtt-no-pragmas`. Compile with `-DPLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD`; never set `STBI_NO_STDIO`, which breaks `plutovg-surface.c`. Compiler warnings seen are recorded in `tools/vendor-warnings.txt`, which `tools/update-plutosvg` copies into `PROVENANCE`.
- `vendor.yaml` runs `tools/verify-vendor` and `tools/check-symbols` on every push, so an upstream bump cannot bring a forbidden symbol back.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each commit focused and do not sweep in unrelated files. A pull request explains the user-visible outcome and the rationale, links related issues, lists the checks that were run and the tests that were skipped, and flags platform-sensitive or vendored changes. Performance claims need evidence from `tools/run-benchmarks`.

Never commit or push to the default branch. Work on a branch (`stage-N-<slug>`), open a pull request, and leave it for review. Do not merge a pull request unless you are told to.

When you find a defect, in this package, in plutosvg or plutovg, in `zufast` or in an upstream tool, open an issue for it rather than only working around it; a plutosvg or plutovg fix also becomes a patch in `tools/patches/` until upstream releases it.
