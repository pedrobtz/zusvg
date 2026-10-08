hashes <- read.delim(test_path("fixtures", "hashes.tsv"), colClasses = "character")

test_that("every fixture renders to its pinned hash", {
  # Exact hashes are CI's claim, not CRAN's (design D14): a CRAN machine's
  # compiler may contract floating point differently (design §8).
  skip_on_cran()
  for (i in seq_len(nrow(hashes))) {
    h <- hashes[i, ]
    r <- svg_render(svg_read(fixture(h$file)), width = as.numeric(h$width), quiet = TRUE)
    expect_identical(dim(r), as.integer(c(h$height, h$width)), label = h$file)
    expect_identical(render_hash(r), h$md5, label = h$file)
  }
})

test_that("fixtures render the pixels they are about", {
  px <- function(f, x, y, rgba) {
    expect_pixel(svg_render(svg_read(fixture(f)), width = 32, quiet = TRUE), x, y, rgba)
  }
  px("rect.svg", 10, 10, c(0x2a, 0x7a, 0xb0, 255))
  px("rect.svg", 30, 30, c(0, 0, 0, 0))
  px("fill-rule.svg", 4, 4, c(0, 0, 0, 255))
  px("fill-rule.svg", 16, 16, c(0, 0, 0, 0))
  px("image-png.svg", 8, 16, c(255, 0, 0, 255))
  px("image-png.svg", 24, 16, c(0, 0, 255, 255))
  px("use-element.svg", 17, 17, c(0x3d, 0x34, 0x8b, 255))
  px("text.svg", 10, 16, c(0xee, 0xee, 0xee, 255))
  # Unclipped: plutosvg 0.0.8 does not apply clip paths (design D15).
  px("clip-path.svg", 2, 2, c(0x54, 0x5e, 0x75, 255))
  # var() with a fallback and no palette takes the fallback.
  px("var-palette.svg", 8, 16, c(0x88, 0x88, 0x88, 255))
  px("var-palette.svg", 24, 16, c(0, 0, 0, 0))
})
