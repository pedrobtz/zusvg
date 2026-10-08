# zusvg — Roadmap to 0.1.0 (first CRAN release)

Companion to [design.md](design.md). Section references (§) point there.

**Status:** adopted 2026-10-08 from [RFC 0007](https://github.com/pedrobtz/packages/blob/main/rfcs/0007-zusvg-svg-rasteriser.md). Nothing below is implemented; the repository is the `usethis` skeleton (created 2026-10-08 with `dotfiles/create-pkg.sh -c`) plus these documents.

## Sequencing principles

1. **Portability is proven at Stage 0, not discovered at Stage 7.** Vendoring two libraries is the largest schedule risk, and its traps (§9, §14) surface on Windows and under CRAN's compiled-code check. The first stage is a three-platform build of the vendor trees with the symbol check passing.
2. **The pre-scan lands with the loader, before any render.** Limits retrofitted into code that assumes they hold is how limit bugs ship (zucbor's rule).
3. **The simplest output first.** `as = "native"` is one conversion; `"array"` and `"raw"` are derived from it, and PNG and JPEG from the surface. Each later stage inherits the shape tests.
4. **Every stage ends with something runnable and tested.**
5. **A stage is done when its exit criteria pass in CI on all three platforms**, not when the code is written.
6. **Gates need canaries.** `tools/verify-vendor` is trusted once it has failed on a one-byte edit; `tools/check-symbols` once it has failed on a plant; the fuzz target once `fuzz_canary` has crashed.
7. **Change the design in the same commit as the contract.** A stage that changes a decision in §17 edits design.md in that commit.

Sizes are relative: **S** ≈ a sitting, **M** ≈ a few, **L** ≈ the stage is the week.

**Status never goes in a heading.** A heading is `## Stage N — Title · Size` and nothing else; the state is the **Status:** line under it.

**Tracking.** A `v0.1.0` parent issue and one `stage`-labelled sub-issue per stage, each linking to its heading here. None exists on 2026-10-08; Stage 0 opens them and `.github/scripts/stage-cards.sh` in `pedrobtz/packages` puts the parent on the board. Each stage gains a **What actually happened** block when it closes.

## The release order, and what it costs

`LinkingTo: zufast (>= 0.1.0)` is unconditional (the pre-scan's UTF-8 check), so **zufast must be on CRAN before zusvg can be submitted** (alignment R10.5, release order). On 2026-10-08 zufast's `DESCRIPTION` says 0.1.0, but it has no tag, is not submitted, and is not on CRAN. `Remotes: pedrobtz/zufast@main` carries development (R10.2), and Stage 7 removes it. `zukomp` was submitted on 2026-10-06 and is not yet accepted. It enters `LinkingTo` and `Imports` at Stage 6 only if it is on CRAN by then; otherwise `.svgz` and the better PNG compression wait for 0.1.1, and Stage 6 says so in `zusvg_info()`.

Nothing waits on zusvg.

## Working rhythm

One pull request per stage: branch `stage-N-<slug>` from `main`; `devtools::document()`, `devtools::test()`, `devtools::test(shuffle = TRUE)` and `devtools::check(cran = TRUE)` clean at 0/0/0 locally before pushing; the PR body states the stage and its exit criteria as a checklist, carries `Closes #<n>` and the `full-ci` label (every stage touches `src/`, so the full matrix runs before merge); every CI leg green before merging; then update `.claude/CLAUDE.md`'s current-state paragraph and the **Status:** line.

Local traps the siblings hit: roxygen2 must be 8.1.0 or newer; `_R_CHECK_SYSTEM_CLOCK_=0` for offline checks; `tools/check-symbols` must run on an `R CMD INSTALL` build, since `load_all()` compiles with `-UNDEBUG` and keeps `assert()`s in.

## Testing strategy, fixed once

- Self-sufficient tests: inputs built inside each `test_that()`, SVG text written inline or read from `fixtures/`; `withr::local_seed()` for anything random; everything written under `withr::local_tempdir()`.
- Assert on condition classes and fields (`offset`, `limit`, `limit_value`), never message text.
- Serial testthat, no `Config/testthat/parallel`; `shuffle = TRUE` in every definition of done; shared code only in `helper-*.R`.
- Helpers: `helper-svg.R` (`svg_text(...)` building a minimal document around a body; `fixture(name)`), `helper-expect.R` (`expect_zusvg_error(expr, class, ...)`, `expect_render_hash(doc, hash, ...)`, `expect_pixel(raster, x, y, rgba)`), `helper-skip.R` (`skip_heavy()` on `ZUSVG_SKIP_HEAVY`, set by the gctorture and valgrind legs; `skip_if_no_slow_tests()` on `ZUSVG_SLOW_TESTS`; `skip_if_not_installed("rsvg")`).
- Fixtures: the project corpus and the `resvg` subsets under `tests/testthat/fixtures/`, fetched and regenerated only by `tools/update-fixtures`, with `hashes.tsv` of pinned render hashes read with `colClasses = "character"`.
- CRAN budget: under 15 s; the 1 000-document memory test, the large surfaces and the `rsvg` cross-check are `skip_heavy()` or conformance-job only.

## CI, and the stage each workflow lands in

Reusable workflows from `pedrobtz/r-actions`. The scaffold's `R-CMD-check.yaml` and `coverage.yaml` call it at `@v1`. `pkgdown.yaml` uses r-lib's actions directly, because r-actions has no pkgdown workflow. Stage 0 pins every r-actions call by commit and adds Dependabot to move the pins, as alignment R5 recommends. `coverage.yaml` must be pinned regardless, because its badge job holds a write token.

| Workflow | Stage | What it checks |
|---|---|---|
| `R-CMD-check.yaml` (exists) | 0 | runners and the CRAN-like containers; quick on PRs, full on `main` and with `full-ci`; zufast from `Remotes` |
| `coverage.yaml` (exists) | 0 | badge on `main`; pinned by commit; `native: true` |
| `pkgdown.yaml` (exists; r-lib actions) | 0 | the site; `development: mode: auto` |
| `vendor.yaml` | 0 | r-actions `vendor.yml`: `tools/verify-vendor` (trees equal tags plus patches; `PROVENANCE` agrees); a `symbols` job running `tools/check-symbols` on an installed build |
| `vendor-upstream.yaml` | 0 | r-actions `vendor-upstream.yml`: a newer upstream tag opens an issue |
| `native-checks.yaml` | 1 | sanitizers (with `-UNDEBUG`), valgrind, LTO, gctorture, blocking rchk |
| `hardening.yaml` | 5 | `tools/run-fuzz` through r-actions `fuzz.yml` (canary, then `fuzz_svg` under ASan and UBSan with a per-input timeout; cached corpus; nightly long run); `tools/run-lint`; `tools/run-mutation-check`; `tools/check-no-network` |
| `conformance.yaml` | 6 | render hashes equal across Linux, macOS and Windows runners (x86-64 and arm64), or per architecture after design §18 Q9; `rsvg` cross-check within tolerance; `tools/run-benchmarks` informational |

## Stage map

| Stage | Size | Needs | Delivers |
|---|---|---|---|
| 0 — Vendor trees, patch set, tools, first build | L | — | plutosvg and plutovg compiled into a 0/0/0 package on three platforms; `verify-vendor`, `check-symbols`, `PROVENANCE`; the `<use>` depth and `NULL`-check patches; the feature survey; tracking issues |
| 1 — Load, read, size, errors, limits, pre-scan | M | 0 | `svg_load()`, `svg_read()`, `svg_size()`, `svg_validate()`; the §11 classes; the §12 guards |
| 2 — `svg_render()` native; shape tests; fixtures | M | 1 | the surface, canvas and ABGR packing; the project corpus with pinned hashes |
| 3 — `"array"`, `"raw"`, `id`, extents, colours, palette | M | 2 | the rest of the render surface |
| 4 — PNG, JPEG, `svg_elements()`, text warning | S | 3 | `svg_png()`, `svg_jpeg()`, `svg_elements()`, `zusvg_text_skipped` |
| 5 — Fuzz target, mutation check, hardening CI | M | 4 | `fuzz_svg`, `fuzz_canary`, `hardening.yaml`; §18 Q2 decided |
| 6 — `.svgz`, zukomp compression, conformance, benchmarks | M | 5 | `conformance.yaml`; `zukomp` in `LinkingTo` and `Imports` if on CRAN; benchmarks recorded |
| 7 — Site, vignette, CRAN | S | 6, and zufast on CRAN | the submission |

---

## Stage 0 — Vendor trees, patch set, update and verify tools, first build · L

**Status:** in review (#3). Every exit criterion is met locally on macOS arm64; CI on Linux and Windows decides the rest.

**Goal:** both libraries compile into `zusvg.so` on Linux, macOS and Windows, byte-identical to their tags plus a recorded patch set, with no forbidden symbol, and the package checks 0/0/0 before any `svg_*` function exists.

**Do**

- `DESCRIPTION`: `Title: Render 'SVG' Images Without System Dependencies`; a `Description` naming plutosvg, the outputs and what is not supported (text, filters, CSS); `Authors@R` Pedro Baltazar (`aut`, `cre`, `cph`) plus the plutosvg and plutovg copyright holders as `cph` with comments naming the library (re-check the vendored file headers: `grep -h Copyright src/vendor/*/*`); `Depends: R (>= 4.1)`; `LinkingTo: zufast (>= 0.1.0)`; `Remotes: pedrobtz/zufast@main` (development only); `Suggests: rsvg, png, jpeg, grid, ggplot2, testthat (>= 3.0.0), withr, knitr, rmarkdown`; `License: MIT + file LICENSE`; `Copyright: file inst/COPYRIGHTS`; `Language: en-GB`; `Config/roxygen2/version: 8.1.0`; `URL`, `BugReports`; `Config/testthat/edition: 3`, no `parallel`; empty `SystemRequirements`.
- `inst/COPYRIGHTS` with zusvg's, plutosvg's and plutovg's notices and the FTL text; `LICENSE.note`.
- **Re-check upstream first** (zuxml found four releases and four CVEs between its design and its import): the latest tags on 2026-10-08 are plutosvg v0.0.8 and plutovg v1.3.3 (confirmed with `git ls-remote` that day).
- `tools/update-plutosvg <plutosvg-tag> <plutovg-tag>`: fetch both release tarballs, record SHA-256s, copy the listed files (`tools/plutosvg-files.txt`, `tools/plutovg-files.txt`: sources and headers, `LICENSE`, `FTL.TXT`; no tests, examples, Meson or CMake files) into `src/vendor/`, apply `tools/patches/*.patch` in order, write `src/vendor/PROVENANCE`. `tools/verify-vendor` re-derives the trees and fails on any difference, including a stale `PROVENANCE`; seen to fail on a one-byte edit, a stray file and a dropped patch.
- `src/Makevars` as §14: the 12 vendored objects plus the project's, hand-listed; `-DPLUTOVG_BUILD_STATIC -DPLUTOSVG_BUILD_STATIC` and never `-D*_BUILD` (which exports the API past `$(C_VISIBILITY)`, §4); the stb linkage and `STBI_*` flags of design §9 and §14 (not `STBI_NO_STDIO`); `-DPLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD`; the `-I` flags; `PKG_LIBS = -lm`; no `Makevars.win`. `src/init.c` registering `zusvg_info()`; delete `src/zusvg.c`.
- **The first build under `-Wall -Wextra -pedantic`** on all three platforms: record every warning from the vendor trees in `PROVENANCE`; patch what CRAN's flags would print.
- `tools/check-symbols` (`nm -u` over the built objects, the list in design §9: no `stdout`, `stderr`, `printf`, `fprintf`, `fputs`, `puts`, `abort`, `exit`, `assert`, `rand`; the stream symbols too, since clang rewrites `fprintf` into `fwrite`), run on an `R CMD INSTALL` build, where `-DNDEBUG` removes the vendored `assert()`s; seen to fail on a planted `fprintf(stderr, ...)`. Any hit in the vendor trees becomes a patch, never a justification (`packages/templates/package-CLAUDE.md`: zuxml's first upload was rejected at the pretest for exactly that).
- **Write D4's first patches.** The 2026-10-08 reading settled what was open here: 0.0.8's 256-level cap does not cover `<use>` chains (design §9). So:
  - add the depth count to `render_use()`, with a fixture of a long chain that crashed before the patch;
  - add `NULL` checks to every unchecked allocation design §9 lists.

  Record both in `PROVENANCE`, `zusvg_info()` and design §17.
- `zusvg_info()` as the first `.Call`: plutosvg and plutovg version strings from their headers, the patch identifiers (also asserted by `test-info.R`), the `STBI_NO_*` set.
- `vendor.yaml` and `vendor-upstream.yaml` from r-actions.
- **The feature survey** (§18 Q6): render-ability of the icon sets R users pull (Font Awesome, Bootstrap Icons, Material, Lucide) and of the SVGs shipped in a sample of CRAN packages, by counting `<text`, `<filter`, `<style`, `class=`, `<mask` and `<clipPath`/`clip-path` occurrences; record the result in design §3, decide whether D3 or the audience changes, and settle design §18 Q8 (clip paths) from the clip count.
- `.Rbuildignore` (`^\.agents$`, `^\.claude$` added with these documents; `^tools$`, `^fuzz$`, `^cran-comments\.md$`, object patterns), `.gitignore`, `NEWS.md` `# zusvg 0.0.0.9000`, `tests/testthat/test-init.R` (written before the template test is removed), every r-actions call pinned by commit, `.github/dependabot.yml`, `_pkgdown.yml` with `development: mode: auto`.
- `zsg_` was checked free against every sibling's `src/`, `inst/include/` and `R/` on 2026-10-08 (the RFC's `zsv_` is zucsv's vendored zsv library; design D13). Re-check if a sibling has vendored something since.
- Open the tracking issues; create the `stage` and `full-ci` labels; add zusvg to the `parents=` list in `pedrobtz/packages`' `.github/scripts/stage-cards.sh`.

**Exit**

- `devtools::check(cran = TRUE)` 0/0/0 locally; `R-CMD-check.yaml` green on every leg including Windows and the clang containers; R-devel compiles in C23 and oldrel with its default standard.
- `tools/verify-vendor` reproduces the committed trees and has been seen to fail; `tools/check-symbols` passes on the installed build and has been seen to fail; `vendor.yaml` green.
- `zusvg_info()` reports both versions and the patch list; `PROVENANCE` records tags, commits, checksums, file lists, patches and the warnings seen.
- The feature survey's result is in design §3; D3 is confirmed or amended and §18 Q8 is decided.
- The `<use>`-chain fixture crashes without the depth patch and renders with it.
- The tracking issues exist and the parent is on the board.

**Trap:** if a platform fights the build, fix configuration in `Makevars` or a project-owned header first; a patch to the vendor tree is the last resort, and then it goes through `tools/patches/` and `PROVENANCE`.

**Not this stage:** any `svg_*` function beyond `zusvg_info()`.

**What actually happened**

- **Tracking.** Parent #2 and stage issues #3–#10 were opened. The parent went on project 3 directly, because zusvg had no draft card for `stage-cards.sh` to replace; adding it to the script's list is pedrobtz/packages#24.
- **Six patches, not two.** `0001-use-depth` and `0002-loader-alloc-checks` were planned. Four more came from R CMD check itself, and none could be fixed in `Makevars` alone:
  - `0003` guards `STBTT_DEF`, so the build can give stb_truetype external linkage, which ends 30 of the 68 `-Wunused-function` warnings.
  - `0004` removes a variable that GCC reports as set but not used.
  - `0005` replaces the `sprintf()` that external linkage kept alive with `snprintf()`.
  - `0006` removes a diagnostic-suppressing pragma, which the check NOTEs.
- **`0002` covers only plutosvg's loader.** plutovg's growth arrays have no failure path (design §9); Stage 5's allocation-failure job tests them.
- **Configuration found by the build:**
  - `STBIDEF` and `STBIWDEF` set to `extern` for the other 38 unused stb functions.
  - `STBI_NO_THREAD_LOCALS`, because emulated thread-local storage linked libgcc's `abort()` under GCC on macOS. It would do the same under MinGW.
  - `Imports: grDevices` waits for Stage 2, since an unused import is a check NOTE.
- **`check-symbols` is stricter than planned.** It also fails on `sprintf`/`vsprintf` and on any export but `R_init_zusvg`. It was seen to fail on:
  - a planted `fprintf(stderr, ...)`;
  - `-D*_BUILD`, which exported the plutosvg API;
  - stale `-UNDEBUG` objects from `load_all()`.
- **The `.o` trap.** `R CMD build` keeps objects in `src/` subdirectories, and the first check failed on `load_all()`'s `assert()`s for that reason. `.Rbuildignore` now excludes `^src/.*\.o$`.
- **`tools/check-use-chain`** builds a small C driver against the patched tree and against it without `0001`. A 200 000-hop chain renders with the patch and segfaults without it; 30 000 hops (about 1 MB) is enough to crash.
- **The feature survey** is in design §3. D3 stands, D15 decides clip paths, and design §18 Q6 and Q8 are closed.

---

## Stage 1 — `svg_load()`, `svg_read()`, `svg_size()`, errors, limits, pre-scan · M

**Status:** not started.

**Do**

- `src/zsg_scan.h` and `zsg_scan.c`: the pre-scan, R-free, with the §12 guards marked `/* GUARD: name */`: `max_size` (checked in R before the copy and again here), `max_elements` (start tags), `max_depth` (nesting), `images` (`<image` refused when `FALSE`), `<text` counted; the element list for `svg_elements()` (tag, `id`, text in subtree, for the seventeen tags plutosvg builds; design §4); tracking `<`, `>`, `/>`, comments, CDATA and DOCTYPE as plutosvg's loader does; UTF-8 through `zuf_utf8_valid()`; offsets for every refusal.
- `src/zsg_doc.c`: the document external pointer owning a copy of the bytes and the `plutosvg_document_t`; finalizer; `plutosvg_document_load_from_data()` with `width`/`height` or `-1`; a `NULL` return is `zusvg_parse_error` with `offset = NA`, and the byte copy has then already been released through `destroy_func` (design §9).
- `R/load.R`, `R/read.R` (through `R/zu_source.R` copied verbatim from `../zuxml` for opening paths and connections, and zucbor's `zu_read_bounded()` from `../zucbor/R/read.R` for reading in 64 KiB blocks up to `max_size + 1`; zuxml's `zu_read_all()` has no limit), `R/validate.R`, `R/size.R`, `R/args.R`; `print.svg_document`, `dim.svg_document`; `.svgz` detected by gzip magic and refused as `zusvg_unsupported_input` until Stage 6.
- `R/conditions.R`: every §11 class and `?"zusvg-conditions"`.
- Tests: every §11 class this stage can raise, with a crafted input (`zusvg_render_error` and the surface's `zusvg_memory_error` arrive with Stage 2, `zusvg_missing_element` with Stage 3); every §12 limit at its boundary, including `max_pixels`' own ceiling (design §6.1); the pre-scan's offsets; the loader's `NA`; a document with each unsupported element loads; a 1 000-document loop leaves resident size flat (`skip_heavy()`).
- `native-checks.yaml` lands: sanitizers with `-UNDEBUG`, valgrind, LTO, gctorture, blocking rchk.

**Exit**

- Every §11 class reachable without a render has a test; `native-checks.yaml` green; `svg_size()` matches plutosvg's resolution rules on inline documents with `width`/`height`, `viewBox` only, and neither (the fixture corpus arrives in Stage 2).

---

## Stage 2 — `svg_render()` with `as = "native"`; shape tests; fixtures · M

**Status:** not started.

**Do**

- `src/zsg_render.c`: surface and canvas in a finalized external pointer created before any R allocation; sizes computed as doubles and checked first (finite, under plutovg's 32768, within `max_pixels`; design §6.1); background clear; scale and translate from the intrinsic size; `plutosvg_document_render()` with the whole document; ARGB premultiplied → straight RGBA (`plutovg_convert_argb_to_rgba()`) written straight into the `nativeRaster`'s integers, which on little-endian are R's packed ABGR (design §6.2).
- `R/render.R`: `width`/`height`/`scale` resolution (§5), `background` and `color` through `col2rgb(alpha = TRUE)`, `as = "native"` only; `Imports: grDevices` arrives here with its first use (an unused import is a check NOTE).
- A test for `zusvg_render_error` and for the surface's `zusvg_memory_error`.
- `tools/update-fixtures`: the project corpus (one file per element type, `preserveAspectRatio` values, gradients, clip paths, `use`, nested svg, `currentColor`, embedded PNG and JPEG, text) and the `resvg` `structure` and `painting` subsets, with `fixtures/README.md` (sources, licences) and `hashes.tsv` of pinned render hashes at fixed sizes.
- Shape tests: class, `dim()`, pinned pixels; `rasterGrob()` and `rasterImage()` into a `png()` device, read back with `png::readPNG()` and compared by pixel within a tolerance, not by file bytes, which vary with the device backend (`skip_if_not_installed("png")`).
- Exact hash comparisons under `skip_on_cran()`; CRAN-run tests compare pinned pixels within one level (design D14).

**Exit**

- Every fixture renders to its pinned hash on every CI platform (the determinism claim, first checked here). If arm64 and x86-64 differ, find whether floating-point contraction is the cause and decide design §18 Q9 in this stage.
- Rendering 1 000 icons at 64 by 64 leaves resident size flat.

---

## Stage 3 — `"array"`, `"raw"`, `id`, `svg_extents()`, colours, palette · M

**Status:** not started.

**Do**

- `as = "array"` (height × width × 4 doubles, non-premultiplied) and `"raw"` (`dim = c(4, width, height)`), derived from the straight RGBA bytes; `as.raster()` works on the array.
- `id`: render one element cropped to its own extents; `zusvg_missing_element`, with its test.
- `svg_extents()` over `plutosvg_document_extents()` (the drawn content's box); `svg_render()` with one size given scales by the ratio of the box it renders (intrinsic size, or the element's extents with `id`).
- The `rsvg` cross-check's tolerance, set from the fixtures and recorded in design §15.
- `palette`: a named character vector → a C array of `(name, plutovg_color_t)` prepared before rendering; the `plutosvg_palette_func_t` callback looks names up and never touches R.
- Tests: each `as` shape; `rsvg::rsvg()` and `rsvg_raw()` shape parity on fixtures (`skip_if_not_installed("rsvg")`); `currentColor` and `var()` fixtures with pinned pixels; an unknown palette name leaves the variable unresolved.

**Exit**

- Every §5 render argument has a test; the `rsvg` shape parity tests pass where `rsvg` is installed.

---

## Stage 4 — `svg_png()`, `svg_jpeg()`, `svg_elements()`, text warning · S

**Status:** not started.

**Do**

- `svg_png()` and `svg_jpeg()` through plutovg's `stb_image_write` stream functions into a growable buffer owned by the render's external pointer; `file = NULL` returns raw; a path or connection is written from R.
- `svg_elements()`: the element list the pre-scan recorded in Stage 1 (id, tag, `has_text` per subtree), plus `has_clip` (design D15).
- `zusvg_text_skipped`, one per rendering call, with the count, suppressed by `quiet = TRUE`; `zusvg_clip_skipped` likewise (design D15). For it the pre-scan records each `clip-path` reference and whether the `<clipPath>` it names is a single rectangle covering the canvas, which is a no-op and does not warn.
- Tests: PNG bytes pinned per platform (expected identical); `png::readPNG()` reads them back; JPEG decodes with `jpeg::readJPEG()` to within tolerance; the warning class and count; `svg_elements()` on an icon sheet.

**Exit**

- PNG output is byte-identical across CI platforms; every §5 function exists.

---

## Stage 5 — Fuzz target, mutation check, hardening CI · M

**Status:** not started.

**Do**

- `fuzz/fuzz_svg.c`: pre-scan, load and render at 64 by 64 under libFuzzer with the project corpus seeded and a per-input timeout; invariants of §15; `fuzz/fuzz_canary.c` must crash first; `tools/run-fuzz`; `hardening.yaml` with r-actions `fuzz.yml`, 2 minutes per PR and 30 nightly on a cached corpus.
- `tools/run-mutation-check` over every `/* GUARD */` in the pre-scan; `tools/run-lint` on project C; `tools/check-no-network`.
- **Decide §18 Q2**: slow inputs the fuzzer finds go into the corpus. A `<use>` fan-out grows exponentially in a kilobyte (design §12), so the step-counter patch is expected. Add it to D4, and settle its default budget from the corpus.

**Exit**

- The canary has crashed; the PR fuzz budget is clean; every guard has a mutation case; `hardening.yaml` green; §18 Q2 decided and recorded.

---

## Stage 6 — `.svgz` and zukomp compression; conformance and benchmarks · M

**Status:** not started.

**Do**

- If `zukomp` is on CRAN:
  - Add `LinkingTo: zukomp` and `Imports: zukomp`.
  - Read `.svgz` files and gzip-magic raw vectors through `komp_decompress(max_output = max_size)`.
  - Compress PNG through stb's `STBIW_ZLIB_COMPRESS` hook, using zukomp's `zlib` codec (a zlib stream, not raw deflate). Call it through zukomp's C API (`zukomp-r.h`, `R_GetCCallable()`) with a callable that returns a status and never raises an R error. Its buffer comes from `malloc()`, because stb frees it with `free()`.
  - Add the hook's prototype as a one-line D4 patch (design §7).
  - Keep the output byte-identical across platforms. If not: `zusvg_info()` says `.svgz` is unsupported in this version and the item moves to *After 0.1.0*.
- `conformance.yaml`: render hashes compared across Linux, macOS and Windows runners (x86-64 and arm64); the `rsvg` cross-check with its tolerance; `tools/run-benchmarks` against `rsvg` and `magick`, results recorded in design §16.

**Exit**

- Hashes identical on every runner (or the determinism claim amended in design §8 in the same commit); the cross-check within tolerance; benchmarks recorded.

---

## Stage 7 — pkgdown site, vignette, CRAN · S

**Status:** not started. Waits for zufast on CRAN.

**Do**

- Every export documented with `@return` and runnable `@examples`; the package help page's first paragraph names what is not supported (D10); a vignette, *Icons, logos and annotations with zusvg* (an icon sheet, recolouring with `palette`, a `ggplot2` annotation, a Shiny asset); `_pkgdown.yml`; README rewritten; `inst/WORDLIST`; `cran-comments.md` listing the CI legs.
- Remove `Remotes:`; rebuild against zufast's CRAN tarball.
- Verify each §19 acceptance criterion in a table naming what verifies it.
- `Version: 0.1.0` and the NEWS heading; `R CMD check --as-cran --run-donttest` 0/0/0; the `cran-extrachecks` and `review-cran-submission` skills.
- Submit. After acceptance: tag `v0.1.0`, GitHub release, bump to `0.1.0.9000`, close the parent issue.

**Exit:** on CRAN.

---

## Acceptance criteria against stages

| § 19 | Criterion | Stage |
|---|---|---|
| 1 | installs everywhere with no system package; clean `--as-cran` | 0, 7 |
| 2 | byte-identical renders on all runners | 2, 6 |
| 3 | within tolerance of `rsvg` | 3, 6 |
| 4 | 30 minutes of nightly fuzzing clean; canary seen | 5 |
| 5 | every class tested; every guard mutation-checked | 1, 2, 3, 5 |
| 6 | a thousand icons under 0.1 s | 6 |
| 7 | vendor trees verified; only the init symbol exported | 0 |

## Explicitly not in 0.1.0

Text · filters, masks, patterns, markers, CSS sheets · applying clip paths (design D15: a warning in 0.1.0, the patch after) · a `palette` function · vector output · an SVG graphics device · a parsed-tree accessor · `.svgz` and zukomp deflate if zukomp is not on CRAN by Stage 6.

## Risk register

| Risk | Stage | Mitigation |
|---|---|---|
| a vendored file references a forbidden symbol behind a path never taken | 0 | `tools/check-symbols` on the installed build; patch, never justify |
| Windows build of `plutovg-font.c` (`windows.h`, UCRT) | 0 | the first build runs on every leg; configuration before patches |
| unchecked `malloc()` in plutosvg and plutovg dereferences `NULL` under memory pressure | 0, 1 | the `NULL`-check patches; `max_size` and `max_elements` |
| `<use>` chain recursion overflows the C stack (*confirmed 2026-10-08*: 0.0.8's cap does not cover it) | 0, 5 | the depth patch at Stage 0 with a crashing fixture; the fuzzer with a stack limit at Stage 5 |
| `-D*_BUILD` exports the vendored API past `$(C_VISIBILITY)` | 0 | `*_BUILD_STATIC` only (design §4); `tools/check-symbols` |
| plutovg's `int` byte count overflows, or `(int)ceilf()` of a huge size | 1, 2 | sizes checked in R as doubles; `max_pixels` capped below 2^29 (design §6.1) |
| clip paths silently ignored | 4 | design D15: `zusvg_clip_skipped` unless the clip is a no-op; fixtures pin the behaviour |
| renders differ across platforms, including FMA contraction on arm64 | 2, 6 | hashes checked from the first render; §18 Q9; CRAN tests use a tolerance (D14) |
| `<use>` fan-out takes exponential time | 5 | §18 Q2's step counter; known slow inputs in the corpus |
| `stb_image` CVE class in embedded images | all | `STBI_NO_*`; `images = FALSE`; the fuzz corpus includes images; `vendor-upstream.yaml` flags new tags |
| zukomp not on CRAN by Stage 6 | 6 | `.svgz` deferred, stated in `zusvg_info()` |
| the audience needs text (§18 Q6) | 0 | the survey before any render code |

## After 0.1.0

1. `.svgz` and zukomp compression for PNG if they missed Stage 6.
2. The patch that applies clip paths (design D15), offered upstream.
3. A parsed-tree accessor over `zuxml` (§18 Q3) and SVG-to-PDF through `zupdf` (§18 Q4), each when asked.
4. The next plutosvg or plutovg release, through `tools/update-plutosvg`, dropping any patch upstream accepted.
