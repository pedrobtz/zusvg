test_that("a string, a raw vector and a connection load the same document", {
  txt <- svg_text('<rect width="4" height="4"/>')
  a <- svg_load(txt)
  b <- svg_load(charToRaw(txt))
  con <- rawConnection(charToRaw(txt))
  on.exit(close(con))
  c <- svg_load(con)
  for (d in list(a, b, c)) {
    expect_s3_class(d, "svg_document")
    expect_identical(svg_size(d), c(width = 10, height = 10))
  }
})

test_that("a string is document text, never a path", {
  path <- withr::local_tempfile(fileext = ".svg")
  writeLines(svg_text(), path)
  expect_zusvg_error(svg_load(path), "zusvg_parse_error")
})

test_that("a string in another encoding is converted to UTF-8", {
  txt <- svg_text('<g id="café"/>')
  latin <- iconv(txt, "UTF-8", "latin1")
  expect_identical(svg_load(latin)$elements$id, "café")
})

test_that("an already loaded document is refused by svg_load()", {
  d <- svg_load(svg_text())
  expect_zusvg_error(svg_load(d), "zusvg_invalid_argument", arg = "x")
})

test_that("an unusable x is an invalid argument", {
  expect_zusvg_error(svg_load(1), "zusvg_invalid_argument", arg = "x")
  expect_zusvg_error(svg_load(c("a", "b")), "zusvg_invalid_argument", arg = "x")
  expect_zusvg_error(svg_load(NA_character_), "zusvg_invalid_argument", arg = "x")
})

test_that("extra arguments are refused, not ignored", {
  expect_zusvg_error(svg_load(svg_text(), max_sise = 1), "zusvg_invalid_argument",
                     arg = "...")
})

test_that("the prolog plutosvg skips is accepted", {
  txt <- paste0(
    "﻿<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
    "<!-- a comment -->\n",
    "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" [ <!ENTITY a \"b\"> ]>\n",
    svg_text("<![CDATA[ <not a tag> ]]><rect/>")
  )
  expect_s3_class(svg_load(txt), "svg_document")
})

test_that("elements plutosvg does not know load and are skipped with their subtree", {
  body <- paste0(
    "<title>t</title><desc>d</desc><metadata><x:y xmlns:x='u'/></metadata>",
    "<filter id='f'><feGaussianBlur stdDeviation='2'/></filter>",
    "<mask id='m'><rect id='inside'/></mask>",
    "<style>rect { fill: red }</style>",
    "<pattern id='p'/><marker id='k'/>",
    "<rect id='r'/>"
  )
  d <- svg_load(svg_text(body))
  # Only built elements are listed: <svg> and the outer <rect>.
  expect_identical(d$n_elements, 2)
  expect_identical(d$elements$id, "r")
})

test_that("ids, tags and text-in-subtree are recorded for built elements", {
  body <- paste0(
    "<g id=' a '><text>x</text><g id='b'><rect id='c'/></g></g>",
    "<symbol id='s'><path d='M0 0'/></symbol>"
  )
  d <- svg_load(svg_text(body))
  expect_identical(d$elements$id, c("a", "b", "c", "s"))
  expect_identical(d$elements$tag, c("g", "g", "rect", "symbol"))
  expect_identical(d$elements$has_text, c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(d$n_text, 1)
})

test_that("malformed documents are parse errors with the fault's offset", {
  # Unclosed element: the fault is at the end of the input.
  txt <- '<svg width="1" height="1"><g>'
  expect_zusvg_error(svg_load(txt), "zusvg_parse_error", offset = nchar(txt) + 0)
  # Mismatched end tag: at its '<'.
  txt <- '<svg width="1" height="1"><g></rect></svg>'
  expect_zusvg_error(svg_load(txt), "zusvg_parse_error", offset = 29)
  # The root must be <svg>.
  expect_zusvg_error(svg_load('<g/>'), "zusvg_parse_error", offset = 0)
  # A second root.
  txt <- paste0(svg_text(), "<svg/>")
  expect_zusvg_error(svg_load(txt), "zusvg_parse_error", offset = nchar(svg_text()) + 0)
  # Text outside the root.
  expect_zusvg_error(svg_load(paste0("x", svg_text())), "zusvg_parse_error", offset = 0)
  # Unquoted attribute value.
  expect_zusvg_error(svg_load('<svg width=1/>'), "zusvg_parse_error", offset = 0)
  # Empty input.
  expect_zusvg_error(svg_load(""), "zusvg_parse_error", offset = 0)
  # A processing instruction other than the XML declaration.
  expect_zusvg_error(svg_load(paste0("<?pi x?>", svg_text())), "zusvg_parse_error",
                     offset = 0)
})

test_that("a document plutosvg's loader refuses has no offset", {
  # Well-formed, but its size resolves to zero (no viewBox to fall back on).
  expect_zusvg_error(svg_load('<svg width="0" height="0"/>'), "zusvg_parse_error",
                     offset = NA_real_)
})

test_that("input that is not UTF-8 is an encoding error", {
  bytes <- c(charToRaw('<svg id="'), as.raw(0xff), charToRaw('"/>'))
  expect_zusvg_error(svg_load(bytes), "zusvg_encoding_error", offset = NA_real_)
  nul <- c(charToRaw('<svg id="a'), as.raw(0), charToRaw('"/>'))
  expect_zusvg_error(svg_load(nul), "zusvg_encoding_error", offset = 10)
})

gzip_bytes <- function(txt) {
  path <- withr::local_tempfile(.local_envir = parent.frame())
  con <- gzfile(path, "wb")
  writeLines(txt, con)
  close(con)
  readBin(path, "raw", file.size(path))
}

test_that("gzip-compressed input is decompressed", {
  gz <- gzip_bytes(svg_text('<rect id="z"/>'))
  expect_identical(gz[1:2], as.raw(c(0x1f, 0x8b)))
  expect_identical(svg_load(gz)$elements$id, "z")
})

test_that("max_size bounds the decompressed size", {
  txt <- svg_text(strrep(" ", 1e5))
  gz <- gzip_bytes(txt)
  expect_lt(length(gz), 1000)
  expect_zusvg_error(svg_load(gz, max_size = 1000), "zusvg_limit_error",
                     limit = "max_size")
})

test_that("corrupt gzip input is a parse error", {
  gz <- gzip_bytes(svg_text())
  expect_zusvg_error(svg_load(c(gz[1:10], as.raw(1:20))), "zusvg_parse_error")
})

test_that("the container size resolves percentages", {
  txt <- '<svg xmlns="http://www.w3.org/2000/svg" width="50%" height="100%" viewBox="0 0 10 10"/>'
  expect_identical(svg_size(svg_load(txt, width = 200, height = 80)),
                   c(width = 100, height = 80))
  expect_zusvg_error(svg_load(txt, width = 0), "zusvg_invalid_argument", arg = "width")
  expect_zusvg_error(svg_load(txt, height = NA), "zusvg_invalid_argument", arg = "height")
})

test_that("print() and dim() describe the document", {
  d <- svg_load(svg_text("<text>a</text><rect/>", 'width="10.5" height="3"'))
  expect_identical(dim(d), c(3, 11))
  expect_output(print(d), "10.5 x 3, 2 elements \\(1 text element will not render\\)")
})

test_that("a document saved and restored must be loaded again", {
  d <- svg_load(svg_text())
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(d, path)
  e <- readRDS(path)
  expect_zusvg_error(svg_size(e), "zusvg_invalid_argument", arg = "x")
})

test_that("loading many documents leaves resident memory flat", {
  skip_heavy()
  skip_if_not(file.exists("/proc/self/status"), "needs /proc")
  rss <- function() {
    s <- readLines("/proc/self/status")
    as.numeric(sub("\\D+(\\d+).*", "\\1", grep("^VmRSS", s, value = TRUE)))
  }
  big <- svg_text(strrep('<rect width="1" height="1"/>', 1000))
  for (i in 1:50) svg_load(big)
  gc()
  before <- rss()
  for (i in 1:1000) svg_load(big)
  gc()
  # Kilobytes. Each document holds over 100 KB in C (its 28 KB of bytes and
  # plutosvg's heap of elements and attributes), so 1000 leaked ones would
  # be over 100 MB.
  expect_lt(rss() - before, 15000)
})
