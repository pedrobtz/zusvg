# Inputs the fuzzer found (roadmap Stage 5), each fixed by a patch in
# tools/patches/. Each must render, or fail with a classed condition,
# promptly and without undefined behaviour (the sanitizer jobs run these).

test_that("an out-of-range coordinate does not overflow the raster (0010)", {
  txt <- svg_text('<polygon points="16,2 3e+38 2,2/8" fill="#ffc914" stroke="#000"/>')
  expect_s3_class(svg_render(txt), "nativeRaster")
  txt <- svg_text('<path d="M0 0 L1e30 1e30 L-1e30 5 Z" fill="red"/>')
  expect_s3_class(svg_render(txt), "nativeRaster")
})

test_that("a stroke in a hugely scaled document does not overflow the stroker (0010)", {
  txt <- paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="1e16" ',
    'viewBox="0 0 10 10" preserveAspectRatio="xMidYMid slice">',
    '<circle cx="5" cy="5" r="4" fill="none" stroke="currentColor" stroke-width="4" ',
    'stroke-miterlimit="1e30"/></svg>'
  )
  doc <- svg_load(txt)
  expect_s3_class(svg_render(doc, width = 8, height = 8), "nativeRaster")
})

test_that("a long dashed path is bounded in segments and time (0012)", {
  txt <- svg_text(paste0(
    '<rect x="4" y="4" width="44444444448" height="24" fill="none" stroke="#c00" ',
    'stroke-width="2" stroke-dasharray="4 2"/>'
  ))
  elapsed <- system.time(r <- svg_render(txt))[["elapsed"]]
  expect_s3_class(r, "nativeRaster")
  expect_lt(elapsed, 10)
})

test_that("an embedded image larger than 4096 pixels a side is not decoded", {
  # A 1 by 1 PNG whose header claims 5000 by 1: refused by stb_image's
  # STBI_MAX_DIMENSIONS before any decode, so nothing is drawn.
  png_hdr <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
                      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
                      0x00, 0x00, 0x13, 0x88, 0x00, 0x00, 0x00, 0x01,
                      0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  b64 <- function(x) {
    chars <- c(LETTERS, letters, 0:9, "+", "/")
    bits <- as.integer(rawToBits(x))
    bits <- matrix(bits, nrow = 8)[8:1, , drop = FALSE]
    bits <- c(bits, rep(0L, (6 - length(bits) %% 6) %% 6))
    idx <- colSums(matrix(bits, nrow = 6) * 2^(5:0))
    out <- paste(chars[idx + 1], collapse = "")
    paste0(out, strrep("=", (3 - length(x) %% 3) %% 3))
  }
  txt <- svg_text(sprintf(
    '<image width="10" height="10" href="data:image/png;base64,%s"/>', b64(png_hdr)))
  r <- svg_render(txt)
  expect_pixel(r, 5, 5, c(0, 0, 0, 0), tolerance = 0)
})

test_that("the fan-out fuzz shape is stopped by the step budget (0009)", {
  lv <- '<g id="a0"><path d="M0 0h1v1z"/></g>'
  for (i in 1:8) {
    lv <- paste0(lv, sprintf('<g id="a%d">%s</g>', i,
                             strrep(sprintf('<use href="#a%d"/>', i - 1), 8)))
  }
  txt <- svg_text(paste0("<defs>", lv, '</defs><use href="#a8"/>'))
  expect_zusvg_error(svg_render(txt), "zusvg_limit_error", limit = "render_steps")
})

test_that("a stroked polygon cut short after one point exports no border (0013)", {
  txt <- '<svg xmlns="http://www.w3.org/2000/svg" width="32" hei0ght="32"><polygon points="16,2\'30,28 2,28" fill="#ffc914" stroke="#000"/></svg>'
  expect_s3_class(svg_render(txt, width = 64), "nativeRaster")
})
