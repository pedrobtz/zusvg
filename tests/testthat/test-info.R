test_that("zusvg_info() reports the pinned libraries", {
  info <- zusvg_info()
  expect_s3_class(info, "zusvg_info")
  # The library's own version string must agree with the tag it was vendored
  # from; a re-vendor that updates one and not the other fails here.
  expect_identical(info$plutosvg$version, "0.0.8")
  expect_identical(info$plutosvg$tag, "v0.0.8")
  expect_identical(info$plutovg$version, "1.3.3")
  expect_identical(info$plutovg$tag, "v1.3.3")
  expect_match(info$plutosvg$commit, "^[0-9a-f]{40}$")
  expect_match(info$plutovg$commit, "^[0-9a-f]{40}$")
})

test_that("zusvg_info() lists every local patch, in order", {
  # Literal on purpose: adding, dropping or reordering a patch in
  # tools/patches/ must be a deliberate change here too (design D4).
  expect_identical(
    zusvg_info()$patches,
    c(
      "0001-use-depth", "0002-loader-alloc-checks", "0003-stbtt-def-guard",
      "0004-stroker-unused-point", "0005-stbiw-snprintf",
      "0006-stbtt-no-pragmas", "0007-bsearch-const",
      "0008-use-symbol-size", "0014-stbiw-jpg-unsigned-bits"
    )
  )
})

test_that("the bundled libraries load and render a known document", {
  expect_true(zusvg_info()$smoke_ok)
})

test_that("zusvg_info() prints", {
  expect_output(print(zusvg_info()), "plutosvg:  0.0.8")
  expect_output(print(zusvg_info()), "self-test: ok")
})
