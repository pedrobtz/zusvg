## Submission

First submission.

zusvg bundles the plutosvg (0.0.8) and plutovg (1.3.3) C libraries, MIT
licensed, with FreeType-derived code under the FreeType Licence and the stb
single-file libraries; every copyright holder is listed as `cph` in
`Authors@R`, and the notices are in `inst/COPYRIGHTS`. The bundled sources
carry seventeen local patches, each recorded in `src/vendor/PROVENANCE` and
offered upstream: they fix undefined behaviour and unbounded work found by
fuzzing, and remove what R CMD check reports (compiler warnings, a
`sprintf()` call, a diagnostic-suppressing pragma).

## Test environments

The package's GitHub Actions run `R CMD check --as-cran` on:

* ubuntu-latest: R release and oldrel-1
* macos-latest (arm64): R release
* windows-latest: R release and R-devel
* R-devel containers: `clang23` (C23), `ubuntu-clang` and `ubuntu-gcc16`
* `nosuggests` (no suggested packages) and `nold` (no long doubles)

and, on every change, UBSan, ASan, valgrind, LTO, gctorture and rchk, a
libFuzzer run over the parser and renderer, and a render-hash comparison
across Linux, macOS and Windows on x86-64 and arm64.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Method References

There are no published references describing the methods in this package.
It wraps the plutosvg and plutovg libraries, cited in `Description` and
`inst/COPYRIGHTS`.
