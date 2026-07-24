# TODO 03 — Binary primitives & codec (shared Bindata types)

**Priority:** P0
**Depends on:** 01
**Status:** pending

## Context

All three formats (WMF, EMF, EMF+) share a set of small binary primitives declared by the Microsoft specs: `RECTL`, `POINTL`, `POINTS`, `POINTD` (`POINT_S` in kaitai), `SIZEL`, `COLORREF`, `XFORM`, `LOGPALETTE` entries, etc. Define them once as bindata primitives, used by every record's wire layer.

Also: text in EMF is stored as UTF-16LE (with optional codepage hinting for legacy records). Encoding conversion is a separate concern from binary parsing and lives in `Emf::Binary::Codec`.

## Outcomes

- `lib/emf/binary/types.rb` declares the shared bindata primitives listed below.
- `lib/emf/binary/codec.rb` provides `Emf::Binary::Codec.utf16le_to_utf8(bytes)`, `.cp1252_to_utf8(bytes)`, and `.detect_and_decode(comment_record)`.
- All primitives are round-trippable (read → write → byte-identical).
- Specs cover every primitive with edge values (zero, max, min, negative for signed).

## Bindata primitives to declare

| Name | Layout | Spec ref |
|---|---|---|
| `Types::PointL` | `int32le :x; int32le :y` | MS-EMF 2.2.2.16 |
| `Types::PointS` | `int16le :x; int16le :y` | MS-WMF 2.2.1.12 (kaitai `point_s`) |
| `Types::PointD` | `double_le :x; double_le :y` | MS-EMF 2.2.2.17 (POINTD for BEZIER control points) |
| `Types::SizeL` | `int32le :cx; int32le :cy` | MS-EMF 2.2.2.22 |
| `Types::RectL` | `int32le :left; int32le :top; int32le :right; int32le :bottom` | MS-EMF 2.2.2.8 (RECTL) |
| `Types::RectS` | `int16le :left; int16le :top; int16le :right; int16le :bottom` | MS-WMF 2.2.1.8 (RECTL_WMFS) |
| `Types::ColorRef` | `uint8 :red; uint8 :green; uint8 :blue; uint8 :reserved` | MS-WMF 2.2.1.7 (kaitai `color_ref`) |
| `Types::Color16` | `uint16le` (5-5-5 RGB) | MS-EMF 2.2.2.2 |
| `Types::XForm` | `float_le :m11, :m12, :m21, :m22, :dx, :dy` | MS-EMF 2.2.28 (XFORM) |
| `Types::LogPaletteEntry` | `uint8 :peFlags; uint8 :peRed; uint8 :peGreen; uint8 :peBlue` | MS-WMF 2.2.1.17 (PALETTEENTRY) |
| `Types::LogPalette` | `uint16le :palVersion; uint16le :palNumEntries; array :palPalEntry, type: :log_palette_entry, initial_length: :palNumEntries` | MS-WMF 2.2.2.13 |
| `Types::Uuid` | 16 raw bytes | MS-EMF (EMF+ GUID) |
| `Types::FileTime` | `uint32le :dwLowDateTime; uint32le :dwHighDateTime` | MS-EMF 2.2.2.10 |
| `Types::SmallRect` | alias for `RectS` | |
| `Types::RgnCombineMode` | `uint32le` enum | MS-EMF 2.1.5 (RGN_COMBINE_MODE) |
| `Types::MixMode` | `uint16le` enum | MS-WMF 2.1.22 (transparent=1, opaque=2) |
| `Types::PolyFillMode` | `uint16le` enum | MS-WMF 2.1.27 (alternate=1, winding=2) |
| `Types::BinRasterOp` | `uint16le` enum | MS-WMF 2.1.2 (16 R2_* codes, kaitai `bin_raster_op`) |
| `Types::StretchMode` | `uint32le` enum | MS-EMF 2.1.24 (STRETCH_MODE) |

All bindata primitives use `endian :little` declared at the top of each record.

## Files to create

```
lib/emf/binary.rb                    # namespace + autoload
lib/emf/binary/types.rb              # all primitives above
lib/emf/binary/codec.rb              # text encoding helpers
spec/emf/binary/types_spec.rb        # per-primitive round-trip
spec/emf/binary/codec_spec.rb        # UTF-16 and CP1252 conversions
```

## Patterns

```ruby
# lib/emf/binary/types.rb
require "bindata"

module Emf
  module Binary
    module Types
      class PointL < BinData::Record
        endian :little
        int32 :x
        int32 :y
      end

      class ColorRef < BinData::Record
        endian :little
        uint8 :red
        uint8 :green
        uint8 :blue
        uint8 :reserved, default_value: 0
      end
      # ...
    end
  end
end
```

```ruby
# lib/emf/binary/codec.rb
module Emf
  module Binary
    module Codec
      module_function

      def utf16le_to_utf8(bytes)
        bytes.force_encoding("UTF-16LE").encode("UTF-8")
      end

      def cp1252_to_utf8(bytes)
        bytes.force_encoding("CP1252").encode("UTF-8")
      end
    end
  end
end
```

## Verification

Per-primitive spec covers: zero value, max positive, min negative (for signed), 4-byte alignment. Read known bytes → assert fields → write back → assert byte-identical.

```ruby
# spec/emf/binary/types_spec.rb
RSpec.describe Emf::Binary::Types::PointL do
  it "round-trips a known point" do
    bytes = [10, 0, 0, 0, 20, 0, 0, 0].pack("C*")
    parsed = described_class.read(bytes)
    expect(parsed.x).to eq(10)
    expect(parsed.y).to eq(20)
    expect(parsed.to_binary_s).to eq(bytes)
  end

  it "handles negative coordinates" do
    bytes = [-1].pack("l<") + [-2].pack("l<")
    parsed = described_class.read(bytes)
    expect(parsed.x).to eq(-1)
    expect(parsed.y).to eq(-2)
  end
end
```

## Done when

- [ ] All 18+ primitives declared.
- [ ] `Codec` decodes UTF-16LE and CP1252 correctly.
- [ ] All specs pass.
- [ ] No `require_relative` in the new files.
- [ ] No doubles in specs.
