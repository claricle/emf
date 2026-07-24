# TODO 06 — Format detector (WMF vs EMF vs EMF+ container)

**Priority:** P0
**Depends on:** 05
**Status:** pending

## Context

`Emf.parse(bytes)` needs to dispatch to the right format-specific parser based on the leading bytes. The detection rules are well-defined:

- **WMF with APM (Aldus Placeable)**: starts with magic `0xD7CDC69A` (kaitai `special_header.magic`).
- **WMF standard (no APM)**: first `uint16le` is `1` (memory metafile) or `2` (disk metafile); `uint16le` at offset 2 is `9` or `0x0300` (header_size_words).
- **EMF**: `uint32le` at offset 0 is `1` (signature); bytes at offset `0x28..0x2B` are `0x20, 0x45, 0x4D, 0x46` (ASCII `" EMF"` little-endian uint32 = `0x464D4520`).

EMF+ is not a separate container — it lives inside an EMF as `EMR_COMMENT` records with the EMF+ identifier. So `Emf.detect_format` returns `:emf` for an EMF+ carrier, and the EMF parser exposes the EMF+ sub-stream via `Metafile#emf_plus`.

## Outcomes

- `lib/emf/detector.rb` defines `Emf.detector(bytes)` returning one of `:wmf_apm`, `:wmf_standard`, `:emf`, or raising `Emf::FormatError` for unrecognised input.
- `Emf.detect_format(bytes)` (public, defined on the `Emf` module in `lib/emf.rb`) returns `:wmf`, `:emf`, or raises.
- Robust against short inputs (returns `:unknown` for buffers < 4 bytes; raises `Emf::FormatError` for buffers that look like neither).
- Pure: no I/O, no side effects.

## Detection rules (verified against kaitai ksy + libemf2svg)

```ruby
# lib/emf/detector.rb
module Emf
  module Detector
    APM_MAGIC = 0xD7CDC69A
    EMF_SIGNATURE = 1
    EMF_MAGIC_OFFSET = 0x28
    EMF_MAGIC = 0x464D4520   # " EMF" as little-endian uint32

    module_function

    def call(bytes)
      raise Emf::FormatError, "input too short (#{bytes.bytesize} bytes)" if bytes.bytesize < 4

      case first_uint32_le(bytes)
      when APM_MAGIC then :wmf_apm
      when EMF_SIGNATURE
        return :emf if looks_like_emf?(bytes)
        return :wmf_standard if looks_like_wmf_metaheader?(bytes)
        raise Emf::FormatError, "unrecognised format (signature=1 but no EMF magic or WMF header)"
      else
        return :wmf_standard if looks_like_wmf_metaheader?(bytes)
        raise Emf::FormatError, format("unrecognised format (first uint32=0x%08X)", first_uint32_le(bytes))
      end
    end

    def looks_like_emf?(bytes)
      return false unless bytes.bytesize >= EMF_MAGIC_OFFSET + 4
      read_uint32_le(bytes, EMF_MAGIC_OFFSET) == EMF_MAGIC
    end

    def looks_like_wmf_metaheader?(bytes)
      return false unless bytes.bytesize >= 18
      mt = read_uint16_le(bytes, 0)
      hs = read_uint16_le(bytes, 2)
      [1, 2].include?(mt) && hs == 9
    end

    def first_uint32_le(bytes) = read_uint32_le(bytes, 0)

    def read_uint32_le(bytes, offset)
      bytes.getbyte(offset) | (bytes.getbyte(offset + 1) << 8) | (bytes.getbyte(offset + 2) << 16) | (bytes.getbyte(offset + 3) << 24)
    end

    def read_uint16_le(bytes, offset)
      bytes.getbyte(offset) | (bytes.getbyte(offset + 1) << 8)
    end
  end
end
```

## Public API

In `lib/emf.rb`, define the public `Emf.detect_format` that returns the canonical symbols:

```ruby
module Emf
  def self.detect_format(bytes)
    case Detector.call(bytes)
    when :wmf_apm, :wmf_standard then :wmf
    when :emf then :emf
    end
  end
end
```

## Files

```
lib/emf/detector.rb
spec/emf/detector_spec.rb
```

## Verification

Use real bytes from fixtures plus synthetic edge cases. Pull a 44-byte prefix from one EMF and one APM WMF for the positive cases.

```ruby
RSpec.describe Emf::Detector do
  let(:emf_bytes) { File.read("spec/fixtures/simple/image1.emf", mode: "rb")[0, 64] }
  let(:apm_wmf_bytes) { [0x9A, 0xC6, 0xCD, 0xD7, 0x00, 0x00, ...].pack("C*") }
  let(:standard_wmf_bytes) { [0x01, 0x00, 0x09, 0x00, ...].pack("C*") }

  it "detects EMF from real fixture" do
    expect(described_class.call(emf_bytes)).to eq(:emf)
  end

  it "detects APM WMF" do
    expect(described_class.call(apm_wmf_bytes)).to eq(:wmf_apm)
  end

  it "detects standard WMF" do
    expect(described_class.call(standard_wmf_bytes)).to eq(:wmf_standard)
  end

  it "raises on garbage" do
    expect { described_class.call("hello, world!".b) }.to raise_error(Emf::FormatError)
  end

  it "raises on too-short input" do
    expect { described_class.call("\x00\x00".b) }.to raise_error(Emf::FormatError)
  end
end
```

## Done when

- [ ] `Emf::Detector` handles APM WMF, standard WMF, EMF, garbage, short input.
- [ ] `Emf.detect_format` returns `:wmf` / `:emf`.
- [ ] All specs green.
- [ ] Used by `Emf.parse` (TODO 15) — but stubbed there for now.
