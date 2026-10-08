# zusvg: render SVG images without system dependencies

zusvg renders SVG documents to pixels with bundled copies of the
plutosvg and plutovg C libraries, so it installs from source with no
system library and draws the same pixels on every platform. It is meant
for icons and logos. It does not render text, filters, masks, patterns,
markers, CSS style sheets or clip paths; a document that uses them
renders without them.

## See also

Useful links:

- <https://pedrobtz.github.io/zusvg/>

- <https://github.com/pedrobtz/zusvg>

- Report bugs at <https://github.com/pedrobtz/zusvg/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Samuel Ugochukwu (plutosvg and plutovg, bundled in src/vendor)
  \[copyright holder\]

- The FreeType Project (rasteriser and stroker in
  src/vendor/plutovg/source/plutovg-ft-\*) \[copyright holder\]

- Sean Barrett (stb_image, stb_image_write and stb_truetype in
  src/vendor/plutovg) \[copyright holder\]
