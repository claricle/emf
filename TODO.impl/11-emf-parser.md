# TODO 11 — EMF parser (with 2-pass path association, EMF+ extraction stub)

**Priority:** P0
**Depends on:** 09, 10
**Status:** pending

## Context

The EMF parser is the most complex of the three. It must:

1. Parse the variable-length `ENHMETAHEADER`.
2. Walk records, looking up each by `iType` in the registry, translating to domain.
3. For `EMR_COMMENT` records with the EMF+ identifier (`0x2B464D45`), extract the EMF+ payload and stash it for the EMF+ parser (TODO 14). For now, just preserve the raw bytes.
4. **Two-pass path association** (the C library's `U_emf_onerec_analyse`): EMF defines paths via `BEGINPATH ... ENDPATH` blocks and renders them via later `FILLPATH` / `STROKEPATH` / `STROKEANDFILLPATH` records. Each FILLPATH/STROKEPATH must carry a back-reference to the path definition so emfsvg knows which points to fill. We build this association during Pass 1.
5. Per-record error trapping: bad bytes don't kill the whole parse; the record becomes a `Raw` and an error is logged.

## Outcomes

- `lib/emf/emf/parser.rb` exposes `Emf::Emf::Parser.call(bytes)` returning `Emf::Model::Metafile`.
- The metafile's `records` is the full ordered list.
- The metafile's `errors` is the list of per-record parse failures.
- `Metafile#emf_plus` returns the raw EMF+ byte stream if any EMF+ comment was found (the structured EMF+ parse happens in TODO 14).
- A `lib/emf/emf/path_association.rb` helper builds the path association table during Pass 1, attached to each FillPath/StrokePath/StrokeAndFillPath domain record.
- All 208 EMF fixtures (186 + 21 + 1) parse without crashing.

## Two-pass flow

```ruby
# lib/emf/emf/parser.rb (sketch)
module Emf
  module Emf
    module Parser
      module_function

      def call(bytes)
        io = StringIO.new(bytes)
        header_wire = Binary::Header.read(io)
        header = Model::Emf::Header.from_wire(header_wire)

        raw_records = read_all_records(bytes, header_wire.num_bytes_consumed)
        associations = PathAssociation.build(raw_records)

        domain_records = raw_records.map do |raw|
          translate(raw, associations)
        rescue => e
          errors << Emf::ParseError.new(offset: raw.offset, record_code: raw.iType, message: e.message)
          build_raw_domain(raw)
        end

        emf_plus_bytes = extract_emf_plus_bytes(domain_records)

        Model::Metafile.new(
          format: emf_plus_bytes ? :emf_plus : :emf,
          header: header,
          records: domain_records,
          errors: errors,
          emf_plus: emf_plus_bytes   # bytes only; TODO 14 wraps in a Metafile
        )
      end
    end
  end
end
```

Note: `:emf_plus` as format means the EMF carried an EMF+ stream. emfsvg can choose to render the EMF+ records instead of the EMF fallback.

## Path association

```ruby
# lib/emf/emf/path_association.rb
module Emf
  module Emf
    class PathAssociation
      # Map: render_record_offset => path_record_offset_range
      # Built by walking raw records once and tracking BEGINPATH..ENDPATH spans
      # and their matching FILLPATH/STROKEPATH/STROKEANDFILLPATH callers.

      def initialize
        @table = {}
      end

      def self.build(raw_records)
        new.tap { |a| a.send(:build_from, raw_records) }
      end

      def lookup(render_offset)
        @table[render_offset]
      end

      private

      def build_from(raw_records)
        # state machine: in_path? path_start_offset
        # on BEGINPATH: in_path = true, path_start = current_offset, points = []
        # on ENDPOINT/MOVETOEX/LINETO/etc: append to points
        # on ENDPATH: in_path = false, last_path = [path_start, current_offset, points]
        # on FILLPATH/STROKEPATH/STROKEANDFILLPATH: associate last_path with current_offset
      end
    end
  end
end
```

The C implementation in `libemf2svg/src/lib/emf2svg.c` `U_emf_onerec_analyse` is the behaviour reference (do not copy code, mirror behaviour).

## EMF+ extraction

```ruby
EMF_PLUS_IDENTIFIER = 0x2B464D45   # "EMF+" as little-endian uint32

def extract_emf_plus_bytes(domain_records)
  chunks = domain_records.select { |r| r.is_a?(Model::Emf::Records::Comment) }
                         .select(&:emf_plus?)
                         .map(&:emf_plus_payload)
  return nil if chunks.empty?
  chunks.join
end
```

The `Comment` domain record (TODO 10) exposes:
- `#emf_plus?` — true if the comment identifier is EMF+
- `#emf_plus_payload` — the raw bytes after the identifier
- `#public?`, `#spool?`, `#emf_attributes?` for other comment types

## Resilience

Every record read is wrapped:

```ruby
def read_one_record(io, file_offset)
  start = io.pos
  type_and_size = io.read(8)
  raise Emf::FormatError, "truncated record header at offset #{start}" if type_and_size.nil? || type_and_size.bytesize < 8

  type_id, n_size = type_and_size.unpack("VV")
  payload = io.read(n_size - 8)

  wire_class = Binary::Records.lookup(type_id)
  wire_class.read(type_and_size + payload)
rescue => e
  Emf::ParseError.new(offset: start, record_code: type_id, message: e.message).tap { |err| errors << err }
  RawRecord.new(type_id, n_size, payload)   # preserve bytes for round-trip
end
```

## Files

```
lib/emf/emf/parser.rb
lib/emf/emf/path_association.rb
spec/emf/emf/parser_spec.rb
spec/emf/emf/path_association_spec.rb
spec/emf/emf/fixtures_spec.rb        # iterates over spec/fixtures/emf/
```

## Verification

```ruby
RSpec.describe Emf::Emf::Parser do
  describe "against spec/fixtures/" do
    Dir.glob("spec/fixtures/emf/*.emf").first(20).each do |path|
      it "parses #{File.basename(path)}" do
        bytes = File.read(path, mode: "rb")
        mf = described_class.call(bytes)
        expect(mf).to be_a(Emf::Model::Metafile)
        expect(mf.format).to eq(:emf).or eq(:emf_plus)
        expect(mf.header.signature).to eq(0x464D4520)
      end
    end
  end

  describe "EMF+ extraction" do
    it "extracts EMF+ payload from a known EMF+ fixture" do
      bytes = File.read("spec/fixtures/emf/test-000.emf", mode: "rb")  # an EMF+ file
      mf = described_class.call(bytes)
      expect(mf.format).to eq(:emf_plus)
      expect(mf.emf_plus).not_to be_nil
    end
  end
end
```

## Done when

- [ ] All 208 EMF fixtures parse without raising.
- [ ] `Metafile#errors` is empty for clean fixtures.
- [ ] `Metafile#errors` is populated for the 21 `emf-corrupted/` files (each parse either succeeds with errors OR raises `Emf::FormatError` for header-level corruption).
- [ ] EMF+ extraction works for the 19 EMF+ fixtures (TODO 03's analysis identified them).
- [ ] Path association table is built for fixtures that use BEGINPATH.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing, no `send` to private methods.
