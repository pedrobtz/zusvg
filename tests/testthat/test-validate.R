test_that("svg_validate() returns TRUE or the condition, unsignalled", {
  expect_true(svg_validate(svg_text()))
  cnd <- svg_validate("<svg><g></svg>")
  expect_s3_class(cnd, "zusvg_parse_error")
  cnd <- svg_validate(svg_text(), max_size = 5)
  expect_s3_class(cnd, "zusvg_limit_error")
  expect_identical(cnd$limit, "max_size")
})

test_that("svg_validate() still raises an unusable argument", {
  expect_zusvg_error(svg_validate(svg_text(), max_size = 0), "zusvg_invalid_argument")
  expect_zusvg_error(svg_validate(1), "zusvg_invalid_argument")
})
