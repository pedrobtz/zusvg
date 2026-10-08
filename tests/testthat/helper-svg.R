# A minimal document around `body`.
svg_text <- function(body = "", attrs = 'width="10" height="10"') {
  sprintf('<svg xmlns="http://www.w3.org/2000/svg" %s>%s</svg>', attrs, body)
}

fixture <- function(name) test_path("fixtures", name)
