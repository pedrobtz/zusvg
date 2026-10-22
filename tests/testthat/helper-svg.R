# A minimal document around `body`.
svg_text <- function(body = "", attrs = 'width="10" height="10"') {
  sprintf('<svg xmlns="http://www.w3.org/2000/svg" %s>%s</svg>', attrs, body)
}

fixture <- function(name) test_path("fixtures", name)

# The pinned render hashes; data, so every column is read as character.
fixture_hashes <- function() {
  read.delim(test_path("fixtures", "hashes.tsv"), colClasses = "character")
}

# Two rects, red and half-transparent blue, side by side in 10 by 10.
icon <- function() {
  svg_text(paste0(
    '<rect width="5" height="10" fill="#ff0000"/>',
    '<rect x="5" width="5" height="10" fill="#0000ff" fill-opacity="0.5"/>'
  ))
}

# The same in 2 by 2: one pixel column of each.
two_px <- function() {
  svg_text(paste0(
    '<rect width="1" height="2" fill="#ff0000"/>',
    '<rect x="1" width="1" height="2" fill="#0000ff" fill-opacity="0.5"/>'
  ), 'width="2" height="2"')
}

# Three ids: a circle, a rect and an empty group.
sheet <- function() {
  svg_text(paste0(
    '<circle id="a" cx="10" cy="10" r="8" fill="#f00"/>',
    '<rect id="b" x="24" y="4" width="12" height="12" fill="#00f"/>',
    '<g id="empty"/>'
  ), 'width="40" height="20"')
}

# `txt` gzip-compressed, as raw bytes; the file lives as long as the caller.
gzip_bytes <- function(txt) {
  path <- withr::local_tempfile(.local_envir = parent.frame())
  con <- gzfile(path, "wb")
  writeLines(txt, con)
  close(con)
  readBin(path, "raw", file.size(path))
}
