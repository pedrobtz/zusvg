# Changelog

## zusvg 0.0.0.9000

- Bundles plutosvg 0.0.8 and plutovg 1.3.3 with seven local patches.
  `<use>` hops now count against the 256-level render depth. The loader
  fails cleanly when an allocation fails. Five smaller patches remove
  what R CMD check would report: three compiler warnings (one only in
  C23), a [`sprintf()`](https://rdrr.io/r/base/sprintf.html) call and a
  diagnostic-suppressing pragma.
- [`zusvg_info()`](https://pedrobtz.github.io/zusvg/reference/zusvg_info.md)
  reports the bundled versions, their upstream tags and commits, and the
  patches.
