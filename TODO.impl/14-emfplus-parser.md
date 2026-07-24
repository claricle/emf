# TODO 14 — EMF+ parser (consumes EMR_COMMENT payload)

**Priority:** P1
**Depends on:** 11, 13
**Status:** pending

## Context

EMF+ bytes live inside an EMF file's `EMR_COMMENT` records with identifier `0x2B464D45`. TODO 11 extracts the concatenated EMF+ byte stream and stashes it on `Metafile#emf_plus` as raw bytes. This TODO parses those bytes into a nested `Emf::Model::Metafile` with `format: :emf_plus`.

EMF+ records have a 12-byte common header (Type uint16, Flags uint16, Size uint32, DataSize uint32). The first record is always the EMF+ Header. The records can use "continuation" — a single logical record split across multiple `EMR_COMMENT` payloads — handled by the Object record type and the `U_OBJ_ACCUM` mechanism in libUEMF. We replicate this.

## Outcomes

- `lib/emf/emf_plus/parser.rb` exposes `Emf::EmfPlus::Parser.call(bytes)` returning `Emf::Model::Metafile`.
- The parser:
  1. Reads the EMF+ Header (first record).
  2. Walks records, dispatching via the registry.
  3. Handles Object continuation (a single Object split across multiple Comment payloads).
  4. Returns a `Metafile` whose `header` is `Emf::Model::EmfPlus::Header` and `records` is the list of `Emf::Model::EmfPlus::Records::*`.
- Per-record error trapping, same policy as EMF parser.
- The EMF parser (TODO 11) is updated to call `EmfPlus::Parser.call` on the extracted bytes, replacing the raw-bytes stash on `Metafile#emf_plus` with a structured `Metafile`.

## Object continuation

EMF+ Object records can be split: the first chunk has the full header; subsequent chunks are continuation records. The libUEMF approach (`U_OBJ_ACCUM`) accumulates bytes until the Object is complete. We mirror this in a small `ObjectAccumulator` class.

```ruby
# lib/emf/emf_plus/object_accumulator.rb
module Emf
  module EmfPlus
    class ObjectAccumulator
      def initialize
        @buffer = String.new
        @pending_type = nil
      end

      def add(chunk_bytes)
        @buffer << chunk_bytes
      end

      def complete?
        # check if accumulated buffer holds a full Object record
      end

      def flush
        # parse accumulated buffer as a single Object record
        result = EmfPlus::Binary::Records::Object.read(@buffer)
        @buffer.clear
        result
      end
    end
  end
end
```

## Files

```
lib/emf/emf_plus/parser.rb
lib/emf/emf_plus/object_accumulator.rb
spec/emf/emf_plus/parser_spec.rb
spec/emf/emf_plus/object_accumulator_spec.rb
```

## Update to TODO 11

In `lib/emf/emf/parser.rb`, replace:

```ruby
emf_plus: emf_plus_bytes   # raw bytes
```

with:

```ruby
emf_plus: emf_plus_bytes && EmfPlus::Parser.call(emf_plus_bytes)
```

## Verification

```ruby
RSpec.describe Emf::EmfPlus::Parser do
  it "parses EMF+ payload extracted from a known fixture" do
    emf_bytes = File.read("spec/fixtures/emf/test-000.emf", mode: "rb")  # EMF+ carrier
    emf_mf = Emf::Emf::Parser.call(emf_bytes)
    emfplus_mf = emf_mf.emf_plus
    expect(emfplus_mf).to be_a(Emf::Model::Metafile)
    expect(emfplus_mf.format).to eq(:emf_plus)
    expect(emfplus_mf.records.first).to be_a(Emf::Model::EmfPlus::Records::Header)
  end
end
```

## Done when

- [ ] EMF+ payloads parse into a structured `Metafile`.
- [ ] The 19 EMF+ fixtures (identified in TODO 03 analysis) all produce a non-empty EMF+ stream.
- [ ] Object continuation works for multi-chunk Object records.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing.
