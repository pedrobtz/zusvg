test_that("svg_elements() lists the elements with an id, in document order", {
  txt <- svg_text(paste0(
    '<defs><symbol id="s"><path d="M0 0"/></symbol></defs>',
    '<g id="a"><text>x</text><rect id="r"/></g><circle/>',
    '<g id="b"><title id="ignored">t</title></g>'
  ))
  e <- svg_elements(txt)
  expect_identical(names(e), c("id", "tag", "has_text", "has_clip"))
  expect_identical(e$id, c("s", "a", "r", "b"))
  expect_identical(e$tag, c("symbol", "g", "rect", "g"))
  expect_identical(e$has_text, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(e$has_clip, c(FALSE, FALSE, FALSE, FALSE))
})

test_that("an icon sheet is cut into icons by id", {
  sheet <- svg_text(paste0(
    '<g id="one"><circle cx="5" cy="5" r="4" fill="red"/></g>',
    '<g id="two"><rect x="12" y="2" width="6" height="6" fill="blue"/></g>'
  ), 'width="20" height="10"')
  ids <- svg_elements(sheet)$id
  icons <- lapply(ids, function(i) svg_render(sheet, id = i, width = 16))
  expect_identical(lapply(icons, dim), list(c(16L, 16L), c(16L, 16L)))
  expect_pixel(icons[[2]], 8, 8, c(0, 0, 255, 255), tolerance = 0)
})

test_that("has_clip marks clips that change the picture, and their ancestors", {
  txt <- svg_text(paste0(
    '<defs><clipPath id="c"><circle cx="5" cy="5" r="3"/></clipPath>',
    '<clipPath id="full"><rect width="10" height="10"/></clipPath></defs>',
    '<g id="outer"><rect id="clipped" width="10" height="10" clip-path="url(#c)"/></g>',
    '<rect id="noop" width="10" height="10" clip-path="url(#full)"/>',
    '<rect id="styled" width="10" height="10" style="fill:red;clip-path: url(\'#c\')"/>',
    '<rect id="dangling" width="10" height="10" clip-path="url(#nothing)"/>'
  ))
  e <- svg_elements(txt)
  got <- setNames(e$has_clip, e$id)
  expect_identical(got[c("outer", "clipped", "noop", "styled", "dangling", "full")],
                   c(outer = TRUE, clipped = TRUE, noop = FALSE, styled = TRUE,
                     dangling = FALSE, full = FALSE))
})
