# TODO 16 — Round-trip serialization test harness

**Priority:** P0
**Depends on:** 15
**Status:** pending

## Context

A clean-room parser must round-trip: parse → serialize → parse must produce a semantically identical model. Byte-equality is too strict (header field normalisation, padding, alignment), so we compare on the `Stats` histogram and a curated set of fields per record type. This is our strongest correctness signal.

## Outcomes

- `spec/emf/round_trip_spec.rb` walks every non-corrupted fixture in `spec/fixtures/` and asserts Stats-histogram equality.
- A `spec/support/round_trip.rb` helper encapsulates the parse-serialize-parse-compare pattern.
- Failures produce a useful diff (which record type's count changed, which specific fields differ).
- The harness runs in under 10 seconds on the full fixture corpus (~200 files).

## Pattern

```ruby
# spec/support/round_trip.rb
module Emf
  module SpecSupport
    module RoundTrip
      module_function

      def assert_identity(path)
        bytes1 = File.read(path, mode: "rb")
        mf1 = Emf.parse(bytes1)
        bytes2 = Emf.serialize(mf1)
        mf2 = Emf.parse(bytes2)

        stats1 = Visitors::Stats.new.visit_all(mf1).histogram
        stats2 = Visitors::Stats.new.visit_all(mf2).histogram
        expect(stats2).to eq(stats1), -> { histogram_diff(stats1, stats2) }

        # Header invariants
        expect(mf2.header.signature).to eq(mf1.header.signature)
        expect(mf2.header.bounds).to eq(mf1.header.bounds)
      end

      def histogram_diff(a, b)
        keys = (a.keys + b.keys).uniq.sort
        lines = keys.filter_map do |k|
          next if a[k] == b[k]
          "  #{k.inspect}: #{a[k]} -> #{b[k]}"
        end
        "Round-trip histogram drift:\n#{lines.join("\n")}"
      end
    end
  end
end
```

```ruby
# spec/emf/round_trip_spec.rb
RSpec.describe "round-trip identity" do
  include Emf::SpecSupport::RoundTrip

  Dir.glob("spec/fixtures/emf/*.emf").each do |path|
    it "round-trips #{File.basename(path)}" do
      assert_identity(path)
    end
  end

  Dir.glob("spec/fixtures/emf-ea/*.emf").each do |path|
    it "round-trips EA #{File.basename(path)}" do
      assert_identity(path)
    end
  end

  Dir.glob("spec/fixtures/wmf/*.wmf").each do |path|
    it "round-trips WMF #{File.basename(path)}" do
      assert_identity(path)
    end
  end
end
```

## Done when

- [ ] `spec/emf/round_trip_spec.rb` runs.
- [ ] All non-corrupted EMF, EMF-EA, simple, and WMF fixtures pass.
- [ ] Failures produce actionable diffs.
- [ ] Full harness runs in < 10 seconds.
