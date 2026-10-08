# Render fixtures

Each `.svg` here was written for zusvg's tests (MIT, as the package) and is
small enough to read. `hashes.tsv` pins the md5 of each one's pixels when
rendered at 48 pixels wide (`tools/update-fixtures`); it is regenerated only
by `tools/update-fixtures --record`, after understanding why a hash moved.

| File | Covers |
|---|---|
| `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `path` | each shape element |
| `fill-rule`, `stroke-dash`, `transform`, `opacity`, `style-attr` | painting and the `style` attribute |
| `linear-gradient-{pad,reflect,repeat}`, `radial-gradient-user` | gradients, spread methods, both unit systems |
| `use-symbol`, `use-element`, `nested-svg` | structure |
| `par-*` | `preserveAspectRatio` values |
| `viewbox-only` | a document sized by its `viewBox` |
| `currentcolor`, `var-palette` | the colours zusvg supplies |
| `clip-path` | a clip, which plutosvg 0.0.8 does not apply (design D15): pinned unclipped |
| `image-png`, `image-jpeg` | embedded `data:` images, a 4 by 4 PNG and its JPEG conversion |
| `text` | text, which does not render (design D3) |

The `resvg` test-suite subsets the design names (§15) are not imported yet:
their licence is to be confirmed first.
