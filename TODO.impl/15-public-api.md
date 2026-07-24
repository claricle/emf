# TODO 15 — Public API surface

**Priority:** P0
**Depends on:** 07, 11
**Status:** pending

## Context

The public API on the `Emf` module is what users (and emfsvg) call. It must be stable, minimal, and explicit. Replace the placeholder stubs from TODO 01 with the real implementation.

## Outcomes

- `Emf.parse(bytes)` — auto-detect format, dispatch to the right parser, return `Emf::Model::Metafile`.
- `Emf.parse_file(path)` — read the file as binary, call `parse`.
- `Emf.serialize(metafile)` — given a `Metafile`, dispatch to the right serializer (Wmf/Emf/EmfPlus), return bytes.
- `Emf.serialize_file(metafile, path)` — write bytes to file.
- `Emf.detect_format(bytes)` — return `:wmf`, `:emf`, or raise `Emf::FormatError`. Already implemented in TODO 06; here we just re-export it.
- All methods have RDoc-style comments.
- Public API is the ONLY thing documented in the README synopsis (TODO 20).

## Implementation

```ruby
# lib/emf.rb (top-level)
module Emf
  class << self
    # Parse binary bytes into a domain Metafile.
    # Auto-detects WMF vs EMF (and EMF+ inside EMF).
    # Raises Emf::FormatError for unrecognised input.
    # Returns Emf::Model::Metafile; check #errors for per-record failures.
    def parse(bytes)
      case Detector.call(bytes)
      when :wmf_apm, :wmf_standard then Wmf::Parser.call(bytes)
      when :emf then Emf::Parser.call(bytes)
      end
    end

    def parse_file(path)
      parse(File.read(path, mode: "rb"))
    end

    # Serialize a Metafile back to binary bytes.
    # Raises Emf::SerializeError on failure.
    def serialize(metafile)
      case metafile.format
      when :wmf then Wmf::Serializer.call(metafile)
      when :emf, :emf_plus then Emf::Serializer.call(metafile)
      else raise SerializeError, "unknown format: #{metafile.format.inspect}"
      end
    end

    def serialize_file(metafile, path)
      File.binwrite(path, serialize(metafile))
    end

    def detect_format(bytes)
      case Detector.call(bytes)
      when :wmf_apm, :wmf_standard then :wmf
      when :emf then :emf
      end
    end
  end
end
```

## Serializers

Each format owns a `Serializer`:

```ruby
# lib/emf/wmf/serializer.rb
module Emf
  module Wmf
    module Serializer
      module_function

      def call(metafile)
        header_bytes = metafile.header.to_wire.to_binary_s
        records_bytes = metafile.records.map { |r| r.to_wire.to_binary_s }.join
        eof_bytes = Model::Wmf::Records::Eof.new.to_wire.to_binary_s
        header_bytes + records_bytes + eof_bytes
      end
    end
  end
end
```

Same pattern for `Emf::Emf::Serializer` and `Emf::EmfPlus::Serializer`.

## Files

```
lib/emf.rb                                   # update with real API
lib/emf/wmf/serializer.rb
lib/emf/emf/serializer.rb
lib/emf/emf_plus/serializer.rb
spec/emf/api_spec.rb                         # public-API spec
```

## Verification

```ruby
RSpec.describe "Emf public API" do
  describe ".parse_file / .serialize / round-trip" do
    Dir.glob("spec/fixtures/emf/*.emf").first(10).each do |path|
      it "round-trips #{File.basename(path)} via Stats" do
        mf = Emf.parse_file(path)
        reborn = Emf.serialize(mf)
        mf2 = Emf.parse(reborn)
        stats1 = Emf::Visitors::Stats.new.visit_all(mf).histogram
        stats2 = Emf::Visitors::Stats.new.visit_all(mf2).histogram
        expect(stats2).to eq(stats1)
      end
    end
  end

  describe ".detect_format" do
    it "returns :emf for an EMF fixture" do
      bytes = File.read("spec/fixtures/simple/image1.emf", mode: "rb")
      expect(Emf.detect_format(bytes)).to eq(:emf)
    end
  end
end
```

## Done when

- [ ] `Emf.parse` / `.parse_file` work for both WMF and EMF.
- [ ] `Emf.serialize` / `.serialize_file` produce re-parseable bytes.
- [ ] `Emf.detect_format` returns the right symbol.
- [ ] Public API spec passes for at least 10 fixtures of each format.
- [ ] No doubles, no `require_relative`.
