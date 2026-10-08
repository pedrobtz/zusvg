test_that("svg_size() follows plutosvg's resolution rules", {
  # width and height given.
  expect_identical(svg_size(svg_text("", 'width="12" height="7"')),
                   c(width = 12, height = 7))
  # viewBox only.
  expect_identical(svg_size(svg_text("", 'viewBox="0 0 48 24"')),
                   c(width = 48, height = 24))
  # One of width and height, with a viewBox for the ratio.
  expect_identical(svg_size(svg_text("", 'width="24" viewBox="0 0 48 24"')),
                   c(width = 24, height = 12))
  # Neither: 300 by 150.
  expect_identical(svg_size(svg_text("", "")), c(width = 300, height = 150))
  # Units.
  expect_identical(svg_size(svg_text("", 'width="1in" height="2pt"'))[["width"]], 96)
})

test_that("svg_size() loads what it is given, passing the limits on", {
  expect_zusvg_error(svg_size(svg_text(), max_size = 5), "zusvg_limit_error")
  d <- svg_load(svg_text())
  expect_zusvg_error(svg_size(d, max_size = 5), "zusvg_invalid_argument", arg = "...")
})
