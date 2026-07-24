# TODO 07 — WMF wire + domain + parser

**Priority:** P1
**Depends on:** 03, 05, 06, 08 (fixtures)
**Status:** pending

## Context

WMF (Windows Metafile) is the oldest of the three formats. The kaitai template at `kaitai-struct-wmf.ksy` is a near-complete binary map. WMF consists of an optional Aldus Placeable header (APM), a standard METAHEADER, then a sequence of records each tagged by a 2-byte function code from a 75-entry table.

There is no WMF implementation in libemf2svg — only the type definitions in `libUEMF-0.2.5/uwmf.h`. The kaitai spec is our authoritative reference.

## Outcomes

- WMF parsing end-to-end: bytes → `Emf::Model::Metafile` with `format: :wmf`.
- All 75+ function codes from `kaitai-struct-wmf.ksy` have a wire record class and a domain record class.
- WMF serialization: `Metafile` → bytes, byte-faithful when no semantic normalisation is applied.
- Fixtures from TODO 08 are exercised in the spec.

## Structure

```
lib/emf/wmf.rb                                 # namespace
lib/emf/wmf/parser.rb                          # bytes → Metafile
lib/emf/wmf/detector.rb                        # extracted from TODO 06 (or kept inline)
lib/emf/wmf/binary.rb
lib/emf/wmf/binary/placeable_header.rb         # APM (Aldus)
lib/emf/wmf/binary/header.rb                   # METAHEADER
lib/emf/wmf/binary/records.rb                  # namespace + autoload + FUNC_TO_NAME + lookup
lib/emf/wmf/binary/records/raw.rb              # unknown function code (preserves bytes)
lib/emf/wmf/binary/records/eof.rb              # META_EOF
lib/emf/wmf/binary/records/set_map_mode.rb
lib/emf/wmf/binary/records/set_window_ext.rb
lib/emf/wmf/binary/records/set_window_org.rb
lib/emf/wmf/binary/records/set_viewport_ext.rb
lib/emf/wmf/binary/records/set_viewport_org.rb
lib/emf/wmf/binary/records/set_bk_mode.rb
lib/emf/wmf/binary/records/set_bk_color.rb
lib/emf/wmf/binary/records/set_text_color.rb
lib/emf/wmf/binary/records/set_poly_fill_mode.rb
lib/emf/wmf/binary/records/set_rop2.rb
lib/emf/wmf/binary/records/set_text_align.rb
lib/emf/wmf/binary/records/save_dc.rb
lib/emf/wmf/binary/records/restore_dc.rb
lib/emf/wmf/binary/records/line_to.rb
lib/emf/wmf/binary/records/move_to.rb
lib/emf/wmf/binary/records/polygon.rb
lib/emf/wmf/binary/records/polyline.rb
lib/emf/wmf/binary/records/poly_polygon.rb
lib/emf/wmf/binary/records/rectangle.rb
lib/emf/wmf/binary/records/round_rect.rb
lib/emf/wmf/binary/records/ellipse.rb
lib/emf/wmf/binary/records/arc.rb
lib/emf/wmf/binary/records/pie.rb
lib/emf/wmf/binary/records/chord.rb
lib/emf/wmf/binary/records/text_out.rb
lib/emf/wmf/binary/records/ext_text_out.rb
lib/emf/wmf/binary/records/set_pixel.rb
lib/emf/wmf/binary/records/create_pen_indirect.rb
lib/emf/wmf/binary/records/create_brush_indirect.rb
lib/emf/wmf/binary/records/create_font_indirect.rb
lib/emf/wmf/binary/records/create_pattern_brush.rb
lib/emf/wmf/binary/records/create_palette.rb
lib/emf/wmf/binary/records/create_region.rb
lib/emf/wmf/binary/records/delete_object.rb
lib/emf/wmf/binary/records/select_object.rb
lib/emf/wmf/binary/records/select_palette.rb
lib/emf/wmf/binary/records/realize_palette.rb
lib/emf/wmf/binary/records/dib_bit_blt.rb
lib/emf/wmf/binary/records/dib_stretch_blt.rb
lib/emf/wmf/binary/records/stretch_dib.rb
lib/emf/wmf/binary/records/bit_blt.rb
lib/emf/wmf/binary/records/stretch_blt.rb
lib/emf/wmf/binary/records/escape.rb
lib/emf/wmf/binary/records/...(remaining 30 types — see kaitai `func` enum)

lib/emf/model/wmf.rb                           # namespace
lib/emf/model/wmf/header.rb                    # domain WMF header (APM-aware)
lib/emf/model/wmf/records.rb
lib/emf/model/wmf/records/*.rb                 # mirror of binary/records/, one domain class per wire class
```

## Wire record pattern

```ruby
# lib/emf/wmf/binary/records/polygon.rb
module Emf
  module Wmf
    module Binary
      module Records
        class Polygon < Emf::Binary::Record
          endian :little
          uint32 :size, value: -> { num_bytes }            # in WMF words (size*2 = byte length)
          uint16 :function, initial_value: 0x0324           # META_POLYGON
          int16 :num_points
          array :points, type: :point_s, initial_length: :num_points
        end
      end
    end
  end
end
```

Wait — in WMF, the size field is the **total record length in words** including the size field itself, so `bytes_size = size * 2 - 6` for the payload after size+function. Bindata handles this via a virtual `:num_bytes`.

For records where the function code implies a fixed payload shape, bindata declares it directly. For variable-shape records, the size field drives the array lengths.

## Domain record pattern

```ruby
# lib/emf/model/wmf/records/polygon.rb
module Emf
  module Model
    module Wmf
      module Records
        class Polygon < Emf::Model::Record
          Visitor.register_visit(:visit_wmf_polygon)

          FUNC_CODE = 0x0324

          def initialize(points:)
            @points = points.freeze
          end

          attr_reader :points

          def type_id = FUNC_CODE

          def self.from_wire(wire)
            new(points: wire.points.map { |p| Geometry::PointS.from_wire(p) })
          end

          def to_wire
            Binary::Records::Polygon.new(
              num_points: points.size,
              points: points.map(&:to_wire)
            )
          end

          def accept(visitor)
            visitor.visit_wmf_polygon(self)
          end
        end
      end
    end
  end
end
```

## Records registry

```ruby
# lib/emf/wmf/binary/records.rb
module Emf
  module Wmf
    module Binary
      module Records
        autoload :Raw, "emf/wmf/binary/records/raw"
        autoload :Eof, "emf/wmf/binary/records/eof"
        autoload :Polygon, "emf/wmf/binary/records/polygon"
        autoload :Polyline, "emf/wmf/binary/records/polyline"
        # ... one autoload per record file

        FUNC_TO_NAME = {
          0x0000 => :Eof,
          0x0102 => :SetBkMode,
          0x0103 => :SetMapMode,
          0x0104 => :SetRop2,
          0x0106 => :SetPolyFillMode,
          0x0127 => :RestoreDc,
          0x020C => :SetWindowExt,
          0x020D => :SetViewportOrg,
          0x0213 => :LineTo,
          0x0214 => :MoveTo,
          0x0324 => :Polygon,
          0x0325 => :Polyline,
          0x041B => :Rectangle,
          0x0418 => :Ellipse,
          0x0817 => :Arc,
          0x0830 => :Chord,
          0x081A => :Pie,
          0x0521 => :TextOut,
          0x0538 => :PolyPolygon,
          0x0A32 => :ExtTextOut,
          0x02FA => :CreatePenIndirect,
          0x02FB => :CreateFontIndirect,
          0x02FC => :CreateBrushIndirect,
          0x01F0 => :DeleteObject,
          0x012D => :SelectObject,
          0x001E => :SaveDc,
          0x0F43 => :StretchDib,
          0x0940 => :DibBitBlt,
          0x0B41 => :DibStretchBlt,
          0x0922 => :BitBlt,
          0x0B23 => :StretchBlt,
          # ... all 75 codes from kaitai
        }.freeze

        def self.lookup(func_code)
          name = FUNC_TO_NAME[func_code]
          name ? const_get(name) : Raw
        end
      end
    end
  end
end
```

## Parser

```ruby
# lib/emf/wmf/parser.rb
module Emf
  module Wmf
    module Parser
      module_function

      def call(bytes)
        io = BinData::IO::Read.new(StringIO.new(bytes))
        apm = read_apm(io, bytes)
        header = read_metaheader(io)
        records = []
        errors = []
        until io.num_bytes_remaining == 0
          offset = io.offset
          record = read_record(io, bytes, offset, errors)
          break if record.is_a?(Model::Wmf::Records::Eof)
          records << record
        end
        Model::Metafile.new(format: :wmf, header: header, records: records, errors: errors)
      end

      def read_record(io, bytes, offset, errors)
        size_word = read_uint16le_at(io, ...)   # bindata-driven
        # ...
      rescue => e
        errors << Emf::ParseError.new(offset: offset, record_code: ..., message: e.message)
        Model::Wmf::Records::Raw.new(...)
      end
    end
  end
end
```

Actual implementation will lean on bindata for the inner reads. The error-trapping loop is the resilience policy.

## Files

Wire layer (~75 files), domain layer (~75 files), parser (1 file), detector (extract from TODO 06 or kept inline). Plus spec/ mirrors.

## Verification

```ruby
RSpec.describe Emf::Wmf::Parser do
  Dir.glob("spec/fixtures/wmf/*.wmf").each do |path|
    it "parses #{File.basename(path)} without crashing" do
      bytes = File.read(path, mode: "rb")
      mf = described_class.call(bytes)
      expect(mf.format).to eq(:wmf)
      expect(mf).to be_a(Emf::Model::Metafile)
    end

    it "round-trips #{File.basename(path)}" do
      bytes = File.read(path, mode: "rb")
      mf = described_class.call(bytes)
      stats_before = Emf::Visitors::Stats.new.visit_all(mf)
      reborn = Emf.serialize(mf)
      mf2 = described_class.call(reborn)
      stats_after = Emf::Visitors::Stats.new.visit_all(mf2)
      expect(stats_after).to eq(stats_before)
    end
  end
end
```

## Done when

- [ ] All 75 kaitai function codes have wire + domain classes.
- [ ] Parser produces a `Metafile` for every WMF fixture (TODO 08).
- [ ] Round-trip via Stats histogram is identical.
- [ ] Unknown function codes (corpus experiments) fall through to `Raw` and don't crash.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing.
