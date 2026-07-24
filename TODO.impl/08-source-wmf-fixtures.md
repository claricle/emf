# TODO 08 — Source WMF fixtures

**Priority:** P1
**Depends on:** — (parallel)
**Status:** pending

## Context

`spec/fixtures/` currently has only EMF files. WMF is a different format with its own record set (META_* function codes), and we cannot validate the WMF parser without real fixtures. The C library `libemf2svg` ships zero WMF support and zero WMF fixtures, so we must source our own.

WMF was once widely used for Office clipart (1990s–early 2000s). Public-domain sources still exist.

## Outcomes

- `spec/fixtures/wmf/` contains at least 20 public-domain WMF files spanning:
  - APM (Aldus Placeable) header variant
  - Standard (no APM) variant
  - Drawing records (LineTo, Polygon, Polyline, Rectangle, Ellipse, Arc)
  - State records (SetBkMode, SetMapMode, SetTextColor)
  - Object records (CreatePenIndirect, CreateBrushIndirect, SelectObject, DeleteObject)
  - Text records (TextOut, ExtTextOut)
  - Bitmap records (StretchDIBits, BitBlt)
  - At least 1 minimal file (just header + EOF)
  - At least 1 large file (> 100 KB)
- `spec/fixtures/wmf/LICENSE.md` documents the source and license of every file.
- All files are public domain (CC0) or BSD/MIT to avoid license entanglement.

## Sources to try (in order)

1. **libwmf test suite** — `https://github.com/caolanm/libwmf/tree/test/test` — historical, public test files.
2. **ImageMagick sample repository** — `https://github.com/ImageMagick/ImageMagick/tree/main/tests` — has WMF inputs.
3. **Wikipedia Commons** — old clipart from the 1990s, often PD-self or CC0.
4. **Microsoft's WMF sample files** — historically distributed with the Win32 SDK.
5. **GIMP / Inkscape test suites** — sometimes include WMF round-trip tests.
6. **Synthetic generation** — if no real fixtures, hand-craft minimal WMF files using the parser's own wire classes (write tests that build a WMF byte-by-byte). This is the fallback.

## Approach

```bash
mkdir -p spec/fixtures/wmf
# (curl/wget commands per source — to be filled in)
# Verify each downloaded file:
for f in spec/fixtures/wmf/*.wmf; do
  hexdump -C "$f" | head -3   # check magic
done
```

For each file, document:
- Source URL
- License (CC0 / PD / BSD / etc.)
- What records it exercises (one-line summary)
- File size

## Synthetic fallback

If we can't source 20 public-domain files, generate them with our own wire layer. This creates a chicken-and-egg dependency on TODO 07, but is acceptable:

```ruby
# spec/support/wmf_factory.rb
module Emf
  module SpecSupport
    module WmfFactory
      module_function

      def minimal_wmf
        Emf::Model::Metafile.new(
          format: :wmf,
          header: ...,
          records: [Emf::Model::Wmf::Records::Eof.new]
        ).then { |mf| Emf.serialize(mf) }
      end

      def polygon_wmf(points: [(0..100).step(10).map { |x| [x, x] }]...)
        # build a WMF with one Polygon record
      end
    end
  end
end
```

## Files

```
spec/fixtures/wmf/*.wmf           # at least 20 files, varied
spec/fixtures/wmf/LICENSE.md      # source + license of every file
spec/fixtures/wmf/README.md       # what each file exercises
```

## Verification

- Every file in `spec/fixtures/wmf/` parses via TODO 07's `Emf::Wmf::Parser`.
- `LICENSE.md` has one entry per file.
- `README.md` lists one-line description per file.

## Done when

- [ ] At least 20 WMF files in `spec/fixtures/wmf/`.
- [ ] Mix of APM and standard headers.
- [ ] Mix of drawing / state / object / text / bitmap record types.
- [ ] LICENSE.md is complete.
- [ ] If sourced externally, no proprietary files included.
