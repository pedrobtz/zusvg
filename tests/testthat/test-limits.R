test_that("max_size is enforced at its boundary", {
  txt <- svg_text()
  n <- nchar(txt, "bytes")
  expect_s3_class(svg_load(txt, max_size = n), "svg_document")
  expect_zusvg_error(svg_load(txt, max_size = n - 1), "zusvg_limit_error",
                     limit = "max_size", limit_value = n - 1)
})

test_that("max_elements counts every start tag, built or skipped", {
  txt <- svg_text("<rect/><title>x</title><g><circle/></g>")
  expect_s3_class(svg_load(txt, max_elements = 5), "svg_document")
  cnd <- expect_zusvg_error(svg_load(txt, max_elements = 4), "zusvg_limit_error",
                            limit = "max_elements", limit_value = 4)
  # The fifth start tag, <circle/>.
  expect_identical(cnd$offset, regexpr("<circle", txt)[[1]] - 1)
})

test_that("max_depth bounds nesting, the root being level 1", {
  txt <- svg_text("<g><g><desc><x/></desc></g></g>")
  expect_s3_class(svg_load(txt, max_depth = 5), "svg_document")
  cnd <- expect_zusvg_error(svg_load(txt, max_depth = 4), "zusvg_limit_error",
                            limit = "max_depth", limit_value = 4)
  expect_identical(cnd$offset, regexpr("<x/>", txt)[[1]] - 1)
})

test_that("images = FALSE refuses an <image> before decoding it", {
  txt <- svg_text('<image href="data:image/png;base64,AAAA"/>')
  expect_s3_class(svg_load(txt), "svg_document")
  expect_zusvg_error(svg_load(txt, images = FALSE), "zusvg_limit_error",
                     limit = "images", limit_value = FALSE,
                     offset = regexpr("<image", txt)[[1]] - 1)
})

test_that("limits are positive whole numbers or Inf", {
  txt <- svg_text()
  expect_s3_class(svg_load(txt, max_elements = Inf, max_depth = Inf), "svg_document")
  for (bad in list(0, -1, 1.5, NA, "1", c(1, 2), NaN)) {
    expect_zusvg_error(svg_load(txt, max_elements = bad), "zusvg_invalid_argument",
                       arg = "max_elements")
  }
  expect_zusvg_error(svg_load(txt, max_size = 2^31), "zusvg_invalid_argument",
                     arg = "max_size")
  expect_zusvg_error(svg_load(txt, images = NA), "zusvg_invalid_argument",
                     arg = "images")
})

test_that("max_size bounds what a connection is read for", {
  txt <- svg_text(strrep(" ", 1000))
  con <- rawConnection(charToRaw(txt))
  on.exit(close(con))
  expect_zusvg_error(svg_load(con, max_size = 100), "zusvg_limit_error",
                     limit = "max_size")
})

test_that("a <use> fan-out is stopped by the render step budget", {
  # Each level uses the previous one ten times: 12 levels would draw 10^12
  # rects from a document of about 2 KB.
  lv <- '<g id="l0"><rect width="1" height="1"/></g>'
  for (i in 1:12) {
    uses <- paste0(rep(sprintf('<use href="#l%d"/>', i - 1), 10), collapse = "")
    lv <- paste0(lv, sprintf('<g id="l%d">%s</g>', i, uses))
  }
  txt <- svg_text(paste0("<defs>", lv, '</defs><use href="#l12"/>'))
  expect_lt(nchar(txt), 3000)
  elapsed <- system.time(
    expect_zusvg_error(svg_render(txt), "zusvg_limit_error", limit = "render_steps")
  )[["elapsed"]]
  expect_lt(elapsed, 10)
})
