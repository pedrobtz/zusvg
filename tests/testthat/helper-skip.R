# The gctorture and valgrind legs set ZUSVG_SKIP_HEAVY: these tests check
# memory and limits, not PROTECT discipline, and would take hours there.
skip_heavy <- function() {
  skip_on_cran()
  if (nzchar(Sys.getenv("ZUSVG_SKIP_HEAVY"))) skip("ZUSVG_SKIP_HEAVY is set")
}

skip_if_no_slow_tests <- function() {
  if (!nzchar(Sys.getenv("ZUSVG_SLOW_TESTS"))) skip("set ZUSVG_SLOW_TESTS to run")
}

# Resident set size in kilobytes (Linux only).
rss_kb <- function() {
  s <- readLines("/proc/self/status")
  as.numeric(sub("\\D+(\\d+).*", "\\1", grep("^VmRSS", s, value = TRUE)))
}

# Runs f() n times twice; the second run must grow RSS by less than kb.
expect_flat_rss <- function(f, n, kb) {
  for (i in seq_len(n)) f()
  gc()
  before <- rss_kb()
  for (i in seq_len(n)) f()
  gc()
  expect_lt(rss_kb() - before, kb)
}

# Under valgrind (Linux: its preload library is mapped into the process)
# everything runs some 50 times slower, so a time bound proves nothing.
running_under_valgrind <- function() {
  maps <- "/proc/self/maps"
  file.exists(maps) && any(grepl("vgpreload", readLines(maps, warn = FALSE), fixed = TRUE))
}

# `elapsed` seconds within `limit`, relaxed thirtyfold under valgrind: the
# point is that the work is bounded, which a hang would still fail.
expect_quick <- function(elapsed, limit) {
  if (running_under_valgrind()) limit <- limit * 30
  expect_lt(elapsed, limit)
}
