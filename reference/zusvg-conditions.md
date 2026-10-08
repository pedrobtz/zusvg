# Conditions raised by zusvg

Every error zusvg raises carries a condition class, so it can be caught
by kind rather than by matching the message, which may change. Every
class below inherits from `zusvg_error`.

## Details

- `zusvg_invalid_argument`:

  An argument was unusable: an input of the wrong type, a limit that is
  not a positive whole number, a bad colour. Carries `arg`, the argument
  at fault.

- `zusvg_parse_error`:

  The document is not one plutosvg can load: it is malformed, its root
  is not `<svg>`, or its size is not positive.

- `zusvg_encoding_error`:

  The input is not UTF-8, or holds a NUL byte.

- `zusvg_limit_error`:

  A limit was reached. Carries `limit`, the argument's name, such as
  `"max_size"`, and `limit_value`.

- `zusvg_missing_element`:

  An `id` is not in the document.

- `zusvg_render_error`:

  plutosvg could not render the document.

- `zusvg_memory_error`:

  An allocation failed.

- `zusvg_io_error`:

  A file or connection could not be read or written.

A `zusvg_parse_error`, `zusvg_encoding_error` or `zusvg_limit_error`
raised while loading carries `offset`, the 0-based byte offset of the
fault in the input, or `NA` when no position is known: plutosvg's loader
reports none, nor does the UTF-8 check.

## Examples

``` r
tryCatch(
  svg_load("<svg><rect></svg>"),
  zusvg_parse_error = function(e) e$offset
)
#> [1] 11
```
