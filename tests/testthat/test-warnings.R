test_that("text that will not render warns once per call, with the count", {
  txt <- svg_text("<text>a</text><g><text>b</text></g>")
  for (f in list(svg_render, svg_png, svg_jpeg)) {
    w <- expect_warning(f(txt), class = "zusvg_text_skipped")
    expect_s3_class(w, "zusvg_warning")
    expect_identical(w$count, 2)
  }
  expect_no_warning(svg_render(txt, quiet = TRUE))
  # Classed, so it can be silenced by class alone.
  expect_no_warning(suppressWarnings(svg_render(txt), classes = "zusvg_text_skipped"))
})

test_that("with id, only text inside that element counts", {
  txt <- svg_text('<g id="a"><text>x</text><rect width="2" height="2"/></g><rect id="b" width="3" height="3"/>')
  expect_warning(svg_render(txt, id = "a"), class = "zusvg_text_skipped")
  expect_no_warning(svg_render(txt, id = "b"))
})

test_that("clips that would change the picture warn; full-canvas clips do not", {
  clip <- svg_text(paste0(
    '<defs><clipPath id="c"><circle cx="5" cy="5" r="3"/></clipPath></defs>',
    '<rect width="10" height="10" clip-path="url(#c)"/>'
  ))
  w <- expect_warning(svg_render(clip), class = "zusvg_clip_skipped")
  expect_identical(w$count, 1)
  noops <- c(
    '<clipPath id="c"><rect width="10" height="10" rx="2"/></clipPath>',
    '<clipPath id="c"><rect width="100%" height="100%"/></clipPath>',
    '<clipPath id="c"><rect x="-1" y="-1" width="20" height="20"/></clipPath>',
    '<clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="1" height="1"/></clipPath>'
  )
  for (n in noops) {
    txt <- svg_text(paste0("<defs>", n, '</defs><rect width="10" height="10" clip-path="url(#c)"/>'))
    expect_no_warning(svg_render(txt))
  }
  # Against the viewBox, not the pixel size.
  vb <- svg_text(paste0(
    '<defs><clipPath id="c"><rect width="100" height="50"/></clipPath></defs>',
    '<rect width="100" height="50" clip-path="url(#c)"/>'
  ), 'width="10" height="5" viewBox="0 0 100 50"')
  expect_no_warning(svg_render(vb))
  # A transformed clip is not assumed to be a no-op.
  tr <- svg_text(paste0(
    '<defs><clipPath id="c" transform="scale(0.5)"><rect width="10" height="10"/></clipPath></defs>',
    '<rect width="10" height="10" clip-path="url(#c)"/>'
  ))
  expect_warning(svg_render(tr), class = "zusvg_clip_skipped")
})

test_that("the lifecycle-badge pattern does not warn about its clip", {
  # A rounded full-canvas clip, as in the badges the survey found (§3).
  badge <- svg_text(paste0(
    '<clipPath id="r"><rect width="80" height="20" rx="3" fill="#fff"/></clipPath>',
    '<g clip-path="url(#r)"><rect width="80" height="20" fill="#555"/></g>'
  ), 'width="80" height="20"')
  expect_no_warning(svg_render(badge))
})
