two_px <- function() {
  svg_text(paste0(
    '<rect width="1" height="2" fill="#ff0000"/>',
    '<rect x="1" width="1" height="2" fill="#0000ff" fill-opacity="0.5"/>'
  ), 'width="2" height="2"')
}

test_that('as = "array" is height x width x 4 in [0, 1], non-premultiplied', {
  a <- svg_render(two_px(), as = "array")
  expect_type(a, "double")
  expect_identical(dim(a), c(2L, 2L, 4L))
  expect_equal(a[1, 1, ], c(1, 0, 0, 1))
  expect_equal(a[2, 2, ], c(0, 0, 1, 128 / 255))
  expect_identical(toupper(as.character(as.raster(a)[1, 1])), "#FF0000FF")
})

test_that('as = "raw" is RGBA bytes with dim c(4, width, height)', {
  r <- svg_render(two_px(), width = 4, height = 2, as = "raw")
  expect_type(r, "raw")
  expect_identical(dim(r), c(4L, 4L, 2L))
  expect_identical(as.integer(r[, 1, 1]), c(255L, 0L, 0L, 255L))
  expect_identical(as.integer(r[, 4, 2]), c(0L, 0L, 255L, 128L))
})

test_that("the three forms hold the same pixels", {
  txt <- readLines(fixture("radial-gradient-user.svg"))
  n <- svg_render(txt, width = 20)
  a <- svg_render(txt, width = 20, as = "array")
  r <- svg_render(txt, width = 20, as = "raw")
  rgba <- render_rgba(n)
  # rgba is row-major (x fastest); the array is [y, x, channel].
  expect_equal(round(a[3, 7, ] * 255), unname(rgba[(3 - 1) * 20 + 7, ]))
  expect_identical(as.integer(r[, 7, 3]), as.integer(rgba[(3 - 1) * 20 + 7, ]))
})

test_that("png::writePNG() takes the native and array forms", {
  skip_if_not_installed("png")
  txt <- two_px()
  for (as in c("native", "array")) {
    path <- withr::local_tempfile(fileext = ".png")
    png::writePNG(svg_render(txt, as = as), path)
    back <- png::readPNG(path)
    expect_equal(back[1, 1, ], c(1, 0, 0, 1), tolerance = 1e-6)
  }
})

test_that("as must be one of the three forms", {
  expect_zusvg_error(svg_render(svg_text(), as = "png"), "zusvg_invalid_argument", arg = "as")
})

sheet <- function() {
  svg_text(paste0(
    '<circle id="a" cx="10" cy="10" r="8" fill="#f00"/>',
    '<rect id="b" x="24" y="4" width="12" height="12" fill="#00f"/>',
    '<g id="empty"/>'
  ), 'width="40" height="20"')
}

test_that("svg_extents() measures the document and its elements", {
  expect_identical(svg_extents(sheet(), id = "b"),
                   c(x = 24, y = 4, width = 12, height = 12))
  expect_identical(svg_extents(sheet()), c(x = 2, y = 2, width = 34, height = 16))
  expect_identical(svg_extents(sheet(), id = "empty")[["width"]], 0)
})

test_that("id renders one element cropped to its extents", {
  r <- svg_render(sheet(), id = "b")
  expect_identical(dim(r), c(12L, 12L))
  expect_pixel(r, 1, 1, c(0, 0, 255, 255), tolerance = 0)
  expect_pixel(r, 12, 12, c(0, 0, 255, 255), tolerance = 0)
  expect_identical(dim(svg_render(sheet(), id = "a", width = 32)), c(32L, 32L))
})

test_that("an unknown id is a missing element; an empty one a render error", {
  expect_zusvg_error(svg_render(sheet(), id = "zz"), "zusvg_missing_element", id = "zz")
  expect_zusvg_error(svg_extents(sheet(), id = "zz"), "zusvg_missing_element")
  expect_zusvg_error(svg_render(sheet(), id = "empty"), "zusvg_render_error")
  expect_zusvg_error(svg_render(sheet(), id = NA_character_), "zusvg_invalid_argument",
                     arg = "id")
})

test_that("palette answers var() by name; an unknown name falls back", {
  f <- readLines(fixture("var-palette.svg"))
  r <- svg_render(f, palette = c(primary = "#00ff00", accent = "navy"))
  expect_pixel(r, 8, 16, c(0, 255, 0, 255), tolerance = 0)
  expect_pixel(r, 24, 16, c(0, 0, 128, 255), tolerance = 0)
  # Names given with the "--" are accepted too.
  r <- svg_render(f, palette = c("--accent" = "red"))
  expect_pixel(r, 24, 16, c(255, 0, 0, 255), tolerance = 0)
  # Not in the palette: the fallback, and none means transparent.
  r <- svg_render(f, palette = c(other = "red"))
  expect_pixel(r, 8, 16, c(0x88, 0x88, 0x88, 255))
  expect_pixel(r, 24, 16, c(0, 0, 0, 0), tolerance = 0)
})

test_that("an unusable palette is an invalid argument", {
  f <- svg_text()
  for (bad in list(c("red"), c(a = "nope"), c(a = "red", a = "blue"), list(a = "red"),
                   c(a = NA_character_))) {
    expect_zusvg_error(svg_render(f, palette = bad), "zusvg_invalid_argument")
  }
})

test_that("<use> sizes a <symbol> by its own width and height (patch 0008)", {
  r <- svg_render(svg_read(fixture("use-symbol.svg")))
  expect_pixel(r, 8, 8, c(0xda, 0x41, 0x67, 255))
  expect_pixel(r, 24, 24, c(0xda, 0x41, 0x67, 255))
  expect_pixel(r, 30, 2, c(0, 0, 0, 0), tolerance = 0)
})

test_that("the array and raw forms have rsvg's shapes", {
  skip_if_not_installed("rsvg")
  txt <- readLines(fixture("rect.svg"))
  path <- withr::local_tempfile(fileext = ".svg")
  writeLines(txt, path)
  expect_identical(dim(svg_render(txt, as = "array")), dim(rsvg::rsvg(path)))
  expect_identical(dim(svg_render(txt, as = "raw")), dim(rsvg::rsvg_raw(path)))
})
