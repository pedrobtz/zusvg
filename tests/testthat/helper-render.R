# The md5 of a nativeRaster's pixels, written as little-endian packed RGBA
# so that the hash is the same on any byte order.
render_hash <- function(r) {
  path <- tempfile()
  on.exit(unlink(path))
  writeBin(as.integer(unclass(r)), path, size = 4L, endian = "little")
  unname(tools::md5sum(path))
}

# The pixels of a nativeRaster as a matrix of r, g, b, a in 0-255, one row
# per pixel in row-major order (x fastest), as the raster stores them.
render_rgba <- function(r) {
  v <- as.numeric(unclass(r))
  v[v < 0] <- v[v < 0] + 2^32
  cbind(r = v %% 256, g = (v %/% 2^8) %% 256, b = (v %/% 2^16) %% 256,
        a = (v %/% 2^24) %% 256)
}

# The pixel at (x, y), 1-based, as c(r, g, b, a).
render_pixel <- function(r, x, y) {
  render_rgba(r)[(y - 1) * ncol(r) + x, ]
}

expect_pixel <- function(r, x, y, rgba, tolerance = 1) {
  got <- render_pixel(r, x, y)
  expect_true(all(abs(got - rgba) <= tolerance),
              label = sprintf("pixel (%d, %d) = (%s), expected (%s)", x, y,
                              paste(got, collapse = ", "), paste(rgba, collapse = ", ")))
}
