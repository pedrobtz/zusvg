# The gctorture and valgrind legs set ZUSVG_SKIP_HEAVY: these tests check
# memory and limits, not PROTECT discipline, and would take hours there.
skip_heavy <- function() {
  skip_on_cran()
  if (nzchar(Sys.getenv("ZUSVG_SKIP_HEAVY"))) skip("ZUSVG_SKIP_HEAVY is set")
}

skip_if_no_slow_tests <- function() {
  if (!nzchar(Sys.getenv("ZUSVG_SLOW_TESTS"))) skip("set ZUSVG_SLOW_TESTS to run")
}
