# zusvg 0.0.0.9000

* Bundles plutosvg 0.0.8 and plutovg 1.3.3 with seven local patches. `<use>`
  hops now count against the 256-level render depth. The loader fails
  cleanly when an allocation fails. Five smaller patches remove what R CMD
  check would report: three compiler warnings (one only in C23), a
  `sprintf()` call and a diagnostic-suppressing pragma.
* `zusvg_info()` reports the bundled versions, their upstream tags and
  commits, and the patches.
