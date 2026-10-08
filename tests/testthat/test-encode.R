icon <- function() {
  svg_text(paste0(
    '<rect width="5" height="10" fill="#ff0000"/>',
    '<rect x="5" width="5" height="10" fill="#0000ff" fill-opacity="0.5"/>'
  ))
}

test_that("svg_png() returns PNG bytes holding the rendered pixels", {
  skip_if_not_installed("png")
  bytes <- svg_png(icon())
  expect_type(bytes, "raw")
  expect_identical(bytes[1:8], as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)))
  img <- png::readPNG(bytes)
  expect_identical(dim(img), c(10L, 10L, 4L))
  a <- svg_render(icon(), as = "array")
  expect_equal(img, a, tolerance = 1e-9)
})

test_that("svg_png() passes the render arguments on", {
  skip_if_not_installed("png")
  img <- png::readPNG(svg_png(icon(), width = 20, background = "white"))
  expect_identical(dim(img), c(20L, 20L, 4L))
  expect_equal(img[10, 15, ], c(0.5, 0.5, 1, 1), tolerance = 0.01)
})

test_that("svg_png() writes a file or a connection", {
  skip_if_not_installed("png")
  path <- withr::local_tempfile(fileext = ".png")
  expect_identical(svg_png(icon(), path), path)
  expect_identical(readBin(path, "raw", 1e5), svg_png(icon()))
  path2 <- withr::local_tempfile(fileext = ".png")
  con <- file(path2, "wb")
  svg_png(icon(), con)
  close(con)
  expect_identical(readBin(path2, "raw", 1e5), svg_png(icon()))
})

test_that("PNG output is pinned (the same bytes on every platform)", {
  skip_on_cran()
  bytes <- svg_png(svg_read(fixture("radial-gradient-user.svg")), width = 48)
  path <- withr::local_tempfile()
  writeBin(bytes, path)
  expect_identical(unname(tools::md5sum(path)), "139297bbc1960c66ca82ed06d293a202")
})

test_that("svg_jpeg() returns a JPEG on white, at the given quality", {
  skip_if_not_installed("jpeg")
  bytes <- svg_jpeg(icon())
  expect_identical(bytes[1:3], as.raw(c(0xff, 0xd8, 0xff)))
  img <- jpeg::readJPEG(bytes)
  expect_identical(dim(img), c(10L, 10L, 3L))
  expect_equal(img[5, 2, ], c(1, 0, 0), tolerance = 0.1)
  # Half-transparent blue over the white default background.
  expect_equal(img[5, 8, ], c(0.5, 0.5, 1), tolerance = 0.1)
  expect_lt(length(svg_jpeg(icon(), quality = 10)), length(svg_jpeg(icon(), quality = 100)))
})

test_that("unusable output arguments are invalid arguments", {
  expect_zusvg_error(svg_jpeg(icon(), quality = 0), "zusvg_invalid_argument", arg = "quality")
  expect_zusvg_error(svg_jpeg(icon(), quality = 50.5), "zusvg_invalid_argument", arg = "quality")
  expect_zusvg_error(svg_png(icon(), file = 1), "zusvg_invalid_argument", arg = "file")
})

test_that("a file that cannot be written is an I/O error", {
  bad <- file.path(withr::local_tempdir(), "no", "such", "dir", "x.png")
  expect_zusvg_error(suppressWarnings(svg_png(icon(), bad)), "zusvg_io_error")
})

test_that("a failed render, encode buffer or surface is a classed error", {
  expect_zusvg_error(zusvg:::zsg_encode(icon(), NULL, 0L, 0L, call = NULL, fail = 1L),
                     "zusvg_memory_error")
  expect_zusvg_error(zusvg:::zsg_encode(icon(), NULL, 0L, 0L, call = NULL, fail = 2L),
                     "zusvg_render_error")
  expect_zusvg_error(zusvg:::zsg_encode(icon(), NULL, 0L, 0L, call = NULL, fail = 3L),
                     "zusvg_memory_error")
})
