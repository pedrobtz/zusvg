test_that("every status C can report maps to a condition class", {
  statuses <- setdiff(.Call(zusvg:::zusvg_status_names), "ZSG_OK")
  expect_setequal(statuses, names(zusvg:::zsg_status_class))
  limits <- names(zusvg:::zsg_status_class)[zusvg:::zsg_status_class == "zusvg_limit_error"]
  expect_setequal(limits, names(zusvg:::zsg_status_limit))
})

test_that("every condition class inherits zusvg_error", {
  cnd <- tryCatch(svg_load("<x/>"), error = identity)
  expect_s3_class(cnd, c("zusvg_parse_error", "zusvg_error", "error", "condition"),
                  exact = TRUE)
})

test_that("conditions name the user's call", {
  cnd <- tryCatch(svg_size("<x/>"), error = identity)
  expect_identical(conditionCall(cnd)[[1]], quote(svg_size))
})
