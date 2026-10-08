test_that("svg_read() reads a file and loads it", {
  path <- withr::local_tempfile(fileext = ".svg")
  writeLines(svg_text('<rect id="a"/>'), path)
  d <- svg_read(path)
  expect_s3_class(d, "svg_document")
  expect_identical(svg_elements(d)$id, "a")
})

test_that("svg_read() passes the container size and the limits on", {
  path <- withr::local_tempfile(fileext = ".svg")
  writeLines('<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="10"/>', path)
  expect_identical(svg_size(svg_read(path, width = 40)), c(width = 40, height = 10))
  expect_zusvg_error(svg_read(path, max_size = 10), "zusvg_limit_error",
                     limit = "max_size")
  expect_zusvg_error(svg_read(path, max_elements = 0), "zusvg_invalid_argument",
                     arg = "max_elements")
})

test_that("svg_read() reads an unopened connection and closes it", {
  path <- withr::local_tempfile(fileext = ".svg")
  writeLines(svg_text(), path)
  before <- nrow(showConnections())
  expect_s3_class(svg_read(file(path)), "svg_document")
  expect_identical(nrow(showConnections()), before)
})

test_that("a missing file or a directory is an invalid argument", {
  expect_zusvg_error(svg_read(tempfile()), "zusvg_invalid_argument", arg = "file")
  expect_zusvg_error(svg_read(tempdir()), "zusvg_invalid_argument", arg = "file")
  expect_zusvg_error(svg_read(1), "zusvg_invalid_argument", arg = "file")
})

test_that("a connection that cannot be read is an I/O error", {
  path <- withr::local_tempfile()
  con <- file(path, "wb")
  on.exit(close(con))
  expect_zusvg_error(svg_read(con), "zusvg_io_error")
})

test_that("an .svgz file is decompressed", {
  path <- withr::local_tempfile(fileext = ".svgz")
  con <- gzfile(path, "wb")
  writeLines(svg_text('<rect id="z"/>'), con)
  close(con)
  expect_identical(svg_elements(svg_read(path))$id, "z")
})
