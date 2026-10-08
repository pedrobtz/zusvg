test_that("svg_render() returns a nativeRaster of the document's size", {
  r <- svg_render(svg_text("", 'width="7" height="3"'))
  expect_s3_class(r, "nativeRaster")
  expect_type(r, "integer")
  expect_identical(dim(r), c(3L, 7L))
  expect_identical(attr(r, "channels"), 4L)
})

test_that("pixels are straight RGBA in R's packed order, row by row", {
  txt <- svg_text(paste0(
    '<rect width="2" height="2" fill="#ff0000"/>',
    '<rect x="2" width="2" height="2" fill="#0000ff" fill-opacity="0.5"/>'
  ), 'width="4" height="2"')
  r <- svg_render(txt)
  expect_pixel(r, 1, 1, c(255, 0, 0, 255), tolerance = 0)
  expect_pixel(r, 4, 2, c(0, 0, 255, 128), tolerance = 0)
})

test_that("the background fills what the document leaves", {
  txt <- svg_text('<rect width="5" height="10" fill="#000"/>')
  expect_pixel(svg_render(txt), 8, 5, c(0, 0, 0, 0), tolerance = 0)
  expect_pixel(svg_render(txt, background = "white"), 8, 5, c(255, 255, 255, 255),
               tolerance = 0)
  expect_pixel(svg_render(txt, background = "#00ff0080"), 8, 5, c(0, 255, 0, 128))
})

test_that("color is what currentColor resolves to", {
  txt <- svg_text('<rect width="10" height="10" fill="currentColor"/>')
  expect_pixel(svg_render(txt), 5, 5, c(0, 0, 0, 255), tolerance = 0)
  expect_pixel(svg_render(txt, color = "orange"), 5, 5, c(255, 165, 0, 255), tolerance = 0)
})

test_that("the surface size follows width, height and scale", {
  txt <- svg_text("", 'width="20" height="10"')
  expect_identical(dim(svg_render(txt)), c(10L, 20L))
  expect_identical(dim(svg_render(txt, scale = 2.5)), c(25L, 50L))
  # One given: the other follows the aspect ratio, rounded up.
  expect_identical(dim(svg_render(txt, width = 7)), c(4L, 7L))
  expect_identical(dim(svg_render(txt, height = 3)), c(3L, 6L))
  # Both given: stretched.
  expect_identical(dim(svg_render(txt, width = 5, height = 9)), c(9L, 5L))
})

test_that("a stretched render fills the whole surface", {
  txt <- svg_text('<rect width="10" height="10" fill="#f00"/>')
  r <- svg_render(txt, width = 30, height = 5)
  expect_pixel(r, 1, 1, c(255, 0, 0, 255), tolerance = 0)
  expect_pixel(r, 30, 5, c(255, 0, 0, 255), tolerance = 0)
})

test_that("max_pixels and plutovg's dimension limit refuse before allocating", {
  txt <- svg_text("", 'width="100" height="100"')
  expect_identical(dim(svg_render(txt, max_pixels = 1e4)), c(100L, 100L))
  expect_zusvg_error(svg_render(txt, max_pixels = 1e4 - 1), "zusvg_limit_error",
                     limit = "max_pixels", limit_value = 1e4 - 1)
  expect_zusvg_error(svg_render(txt, width = 30000), "zusvg_limit_error",
                     limit = "max_pixels")
  expect_zusvg_error(svg_render(txt, width = 32768, height = 1, max_pixels = Inf),
                     "zusvg_limit_error", limit = "dimension", limit_value = 32767)
  expect_zusvg_error(svg_render(txt, max_pixels = 2^29), "zusvg_invalid_argument",
                     arg = "max_pixels")
  # A huge intrinsic size never reaches an int conversion.
  expect_zusvg_error(svg_render(svg_text("", 'width="1e30" height="1"')),
                     "zusvg_limit_error", limit = "dimension")
})

test_that("unusable render arguments are invalid arguments", {
  txt <- svg_text()
  expect_zusvg_error(svg_render(txt, background = "nope"), "zusvg_invalid_argument",
                     arg = "background")
  expect_zusvg_error(svg_render(txt, color = c("red", "blue")), "zusvg_invalid_argument",
                     arg = "color")
  expect_zusvg_error(svg_render(txt, width = -1), "zusvg_invalid_argument", arg = "width")
  expect_zusvg_error(svg_render(txt, scale = 0), "zusvg_invalid_argument", arg = "scale")
  expect_zusvg_error(svg_render(txt, quiet = NA), "zusvg_invalid_argument", arg = "quiet")
})

test_that("svg_render() loads what it is given, passing the limits on", {
  expect_zusvg_error(svg_render(svg_text(), max_size = 5), "zusvg_limit_error",
                     limit = "max_size")
  d <- svg_load(svg_text())
  expect_identical(svg_render(d), svg_render(svg_text()))
})

test_that("a failed surface or render is a classed error", {
  d <- svg_load(svg_text())
  render <- function(fail) {
    zusvg:::zsg_render_native(d, c(10, 10), c(0, 0, 10, 10), c(0, 0, 0, 0),
                              c(0, 0, 0, 1), call = NULL, fail = fail)
  }
  expect_s3_class(render(0L), "nativeRaster")
  expect_zusvg_error(render(1L), "zusvg_memory_error")
  expect_zusvg_error(render(2L), "zusvg_render_error")
})

test_that("grid and graphics draw the raster without conversion", {
  skip_if_not_installed("png")
  r <- svg_render(svg_text('<rect width="10" height="5" fill="#f00"/>'),
                  background = "#00f")
  for (draw in list(
    function() grid::grid.raster(r, interpolate = FALSE),
    function() {
      graphics::par(mar = c(0, 0, 0, 0))
      graphics::plot.new()
      graphics::rasterImage(r, 0, 0, 1, 1, interpolate = FALSE)
    }
  )) {
    path <- withr::local_tempfile(fileext = ".png")
    grDevices::png(path, width = 20, height = 20)
    draw()
    grDevices::dev.off()
    img <- png::readPNG(path)
    # Top half red, bottom half blue, read back from the device.
    expect_equal(img[3, 10, 1:3], c(1, 0, 0), tolerance = 0.05)
    expect_equal(img[17, 10, 1:3], c(0, 0, 1), tolerance = 0.05)
  }
})

test_that("rendering many icons leaves resident memory flat", {
  skip_heavy()
  skip_if_not(file.exists("/proc/self/status"), "needs /proc")
  rss <- function() {
    s <- readLines("/proc/self/status")
    as.numeric(sub("\\D+(\\d+).*", "\\1", grep("^VmRSS", s, value = TRUE)))
  }
  icon <- svg_load(svg_text('<circle cx="5" cy="5" r="4"/>'))
  for (i in 1:50) svg_render(icon, width = 64)
  gc()
  before <- rss()
  for (i in 1:1000) svg_render(icon, width = 64)
  gc()
  expect_lt(rss() - before, 10000)
})
