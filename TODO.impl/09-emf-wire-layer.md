# TODO 09 — EMF wire layer (header + all EMR_* records)

**Priority:** P0
**Depends on:** 03
**Status:** pending

## Context

EMF (Enhanced Metafile) is the format we have the most fixtures for (186 plain + 21 EA + 1 simple = 208 files) and the most complete reference for (libemf2svg has 246 case labels). The wire layer declares the byte-faithful bindata classes for `ENHMETAHEADER` and every `EMR_*` record type.

The authoritative reference is MS-EMF (sections 2.3 records, 2.2 structures, 2.1 enumerations). The C structs in `libUEMF-0.2.5/uemf.h` mirror the spec; we derive bindata classes from the spec, NOT the C code (clean room).

## Outcomes

- `lib/emf/emf/binary/header.rb` declares `ENHMETAHEADER` (variable length, depending on `offDescription` and `nDescription`).
- `lib/emf/emf/binary/records.rb` declares the autoload list + `TYPE_TO_NAME` registry for all 122+ EMR_* type codes.
- `lib/emf/emf/binary/records/*.rb` declares one bindata class per record type.
- All records round-trip via bindata (read known bytes → assert fields → write back → byte-identical).
- Unknown record types fall through to `Raw`.

## EMR_* record type catalog

From `libUEMF-0.2.5/uemf.h` and MS-EMF section 2.3. The full list (122 types). Selected highlights:

- Control: `EMR_HEADER` (1), `EMR_EOF` (14)
- State: `SETMAPMODE` (17), `SETBKMODE` (18), `SETROP2` (20), `SETTEXTALIGN` (22), `SETTEXTCOLOR` (24), `SETBKCOLOR` (25), `SETWORLDTRANSFORM` (26), `MODIFYWORLDTRANSFORM` (27), `SETWINDOWORGEX` (32), `SETWINDOWEXTEX` (33), `SETVIEWPORTORGEX` (34), `SETVIEWPORTEXTEX` (35), `SETBRUSHORGEX` (37), `SETMITERLIMIT` (58), `SAVEDC` (34), `RESTOREDC` (34)
- Object creation: `CREATEPEN` (38), `CREATEBRUSHINDIRECT` (39), `DELETEOBJECT` (40), `CREATEPALETTE` (49), `CREATEPENEX` (95), `CREATEBRUSHINDIRECT` (39), `CREATEFONTINDIRECTW` (82), `CREATEMONOBRUSH` (93), `CREATEDIBPATTERNBRUSHPT` (94), `EXTCREATEPEN` (97), `SELECTOBJECT` (37)
- Drawing: `LINETO` (54), `MOVETOEX` (27), `POLYGON` (3), `POLYGON16` (86), `POLYLINE` (4), `POLYLINE16` (87), `POLYBEZIER` (2), `POLYBEZIER16` (85), `POLYBEZIERTO` (5), `POLYBEZIERTO16` (88), `POLYLINETO` (6), `POLYLINETO16` (89), `POLYPOLYGON` (8), `POLYPOLYGON16` (91), `POLYPOLYLINE` (7), `POLYPOLYLINE16` (90), `POLYDRAW` (24), `POLYDRAW16` (92), `RECTANGLE` (43), `ROUNDRECT` (44), `ELLIPSE` (42), `ARC` (45), `ARCTO` (55), `CHORD` (46), `PIE` (47), `SETPIXELV` (51), `FILLPATH` (62), `STROKEPATH` (64), `STROKEANDFILLPATH` (63), `BEGINPATH` (59), `ENDPATH` (60), `CLOSEFIGURE` (61), `FLATTENPATH` (65), `WIDENPATH` (66), `SELECTCLIPPATH` (67), `ABORTPATH` (68), `GRADIENTFILL` (118), `GRADIENTRECT`, etc.
- Path ops: see BEGINPATH..WIDENPATH above
- Clipping: `INTERSECTCLIPRECT` (30), `EXTSELECTCLIPRGN` (75), `SELECTCLIPPATH` (67), `SETMETARGN` (28), `OFFSETCLIPRGN` (29), `EXCLUDECLIPRECT` (31), `SCALEVIEWPORTEXTEX` (36), `SCALEWINDOWEXTEX` (41), `EXTSELECTCLIPRGN` (75)
- Bitmaps: `BITBLT` (76), `STRETCHBLT` (77), `MASKBLT` (78), `PLGBLT` (79), `SETDIBITSTODEVICE` (80), `STRETCHDIBITS` (81), `ALPHABLEND` (115), `TRANSPARENTBLT` (116), `GRADIENTFILL` (118)
- Text: `EXTTEXTOUTA` (83), `EXTTEXTOUTW` (84)
- Comment: `COMMENT` (105) — carries EMF+, public comments, spool comments, EMF attributes
- Transform: `SETWORLDTRANSFORM` (26), `MODIFYWORLDTRANSFORM` (27)
- EOF: `EOF` (14)

Full reference: MS-EMF section 2.3.1 (record type catalog) and `uwmf.h` lines for the function-code-to-name map.

## ENHMETAHEADER layout

From MS-EMF 2.3.4.2 (EMR_HEADER record type 1):

| Offset | Field | Type |
|---|---|---|
| 0 | iType | uint32 (== 1) |
| 4 | nSize | uint32 |
| 8 | rclBounds | RECTL |
| 24 | rclFrame | RECTL |
| 40 | dSignature | uint32 (== " EMF" = 0x464D4520) |
| 44 | nVersion | uint32 |
| 48 | szlMilliseconds | SIZEL |
| 56 | szlDevice | SIZEL |
| 64 | szlMillimeters | SIZEL |
| 72 | cbPixelFormat | uint32 |
| 76 | offPixelFormat | uint32 |
| 80 | bOpenGL | uint32 |
| 84 | szlMicrometers | SIZEL |
| 92 | offDescription (optional) | uint32 |
| 96 | nDescription (optional) | uint32 |
| 100 | offPalEntries (optional) | uint32 |
| 104 | nPalEntries (optional) | uint32 |
| 108 | ... end of fixed portion (88 bytes for EMF+ variant; 100/108/152 for full header) |

The header is **variable length** — `nSize` tells you the total. The optional description string follows at `offDescription` for `nDescription` Unicode chars.

## Bindata pattern

```ruby
# lib/emf/emf/binary/header.rb
module Emf
  module Emf
    module Binary
      class Header < BinData::Record
        endian :little
        uint32 :iType, initial_value: 1
        uint32 :nSize
        rectl :rclBounds
        rectl :rclFrame
        uint32 :dSignature, initial_value: 0x464D4520
        uint32 :nVersion
        size_l :szlMilliseconds
        size_l :szlDevice
        size_l :szlMillimeters
        uint32 :cbPixelFormat
        uint32 :offPixelFormat
        uint32 :bOpenGL
        size_l :szlMicrometers
        # Optional fields:
        uint32 :offDescription, onlyif: -> { nSize >= 100 }
        uint32 :nDescription, onlyif: -> { nSize >= 100 }
        uint32 :offPalEntries, onlyif: -> { nSize >= 100 }
        uint32 :nPalEntries, onlyif: -> { nSize >= 100 }
        # Description string (Unicode chars * 2 bytes each):
        wide_string :description, length: -> { nDescription.to_i * 2 }, onlyif: -> { nDescription.to_i > 0 }
      end
    end
  end
end
```

Note: `rectl`, `size_l` are custom primitive types from TODO 03 (registered as bindata accepted types).

## Registry

```ruby
# lib/emf/emf/binary/records.rb
module Emf
  module Emf
    module Binary
      module Records
        autoload :Raw, "emf/emf/binary/records/raw"
        autoload :Header, "emf/emf/binary/records/header"
        autoload :Polygon, "emf/emf/binary/records/polygon"
        autoload :Polygon16, "emf/emf/binary/records/polygon16"
        # ... one per EMR_* type

        TYPE_TO_NAME = {
          1 => :Header,
          2 => :PolyBezier,
          3 => :Polygon,
          4 => :Polyline,
          5 => :PolyBezierTo,
          6 => :PolylineTo,
          7 => :PolyPolyline,
          8 => :PolyPolygon,
          9 => :SetWindowOrgEx,
          # ... all 122 codes
        }.freeze

        def self.lookup(type_id)
          name = TYPE_TO_NAME[type_id]
          name ? const_get(name) : Raw
        end
      end
    end
  end
end
```

## Shared record base

Most EMR records have a common 8-byte header (`uint32 iType; uint32 nSize`). Define a shared module:

```ruby
# lib/emf/emf/binary/record.rb
module Emf
  module Emf
    module Binary
      class Record < BinData::Record
        endian :little
        uint32 :iType
        uint32 :nSize
      end
    end
  end
end
```

Every record subclass inherits from this. The size check happens in the parser (validate `nSize` matches actual bytes consumed).

## Files

```
lib/emf/emf.rb
lib/emf/emf/binary.rb
lib/emf/emf/binary/header.rb            # ENHMETAHEADER
lib/emf/emf/binary/record.rb            # shared 8-byte header
lib/emf/emf/binary/records.rb           # namespace + autoload + TYPE_TO_NAME
lib/emf/emf/binary/records/raw.rb
lib/emf/emf/binary/records/*.rb         # ~100 files (one per record type, sharing base)
spec/emf/emf/binary/header_spec.rb
spec/emf/emf/binary/records/*_spec.rb   # per-record round-trip
```

## Verification

For each record, build a known byte string, parse, assert fields, serialize, assert byte-identical. Specs follow this pattern:

```ruby
RSpec.describe Emf::Emf::Binary::Records::Polygon do
  let(:bytes) do
    # iType=3, nSize=24, rclBounds=RECT(0,0,100,100), cptl=1, aptl=[POINT(10,20)]
    [3, 24, 0, 0, 0, 0, 100, 0, 0, 0, 100, 0, 0, 0, 1, 10, 0, 0, 0, 20, 0, 0, 0].pack("V*")
  end

  it "round-trips" do
    parsed = described_class.read(bytes)
    expect(parsed.iType).to eq(3)
    expect(parsed.cptl).to eq(1)
    expect(parsed.aptl.first.x).to eq(10)
    expect(parsed.to_binary_s).to eq(bytes)
  end
end
```

## Done when

- [ ] `ENHMETAHEADER` parses the 88/100/108/152-byte variants.
- [ ] All 122+ EMR_* types have a wire class (or shared base).
- [ ] Registry lookup returns the right class for every known type code.
- [ ] Unknown type codes fall through to `Raw`.
- [ ] All per-record round-trip specs pass.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing.
