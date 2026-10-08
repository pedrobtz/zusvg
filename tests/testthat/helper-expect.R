# Asserts the condition's class and, for each named argument, its field.
expect_zusvg_error <- function(expr, class, ...) {
  cnd <- expect_error(expr, class = class)
  expect_s3_class(cnd, "zusvg_error")
  fields <- list(...)
  for (f in names(fields)) {
    expect_identical(cnd[[f]], fields[[f]], label = paste0("condition$", f))
  }
  invisible(cnd)
}
