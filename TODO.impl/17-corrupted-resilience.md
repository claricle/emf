# TODO 17 — Corrupted-resilience spec

**Priority:** P0
**Depends on:** 11
**Status:** pending

## Context

`spec/fixtures/emf-corrupted/` contains 21 EMF files plus a README documenting exactly what is broken in each. The C library uses these to verify it doesn't crash. Our parser must:

- Never raise an unhandled exception (other than `Emf::FormatError` for header-level corruption).
- Never hang (no infinite loops on truncated input).
- Either return a `Metafile` with `#errors` populated, or raise `Emf::FormatError`.

## Outcomes

- `spec/emf/corrupted_resilience_spec.rb` iterates over `spec/fixtures/emf-corrupted/*.emf`.
- For each file: parse and assert the outcome is one of:
  - `Emf::FormatError` raised (for header corruption)
  - `Emf::Model::Metafile` returned with `has_errors? == true` (for record-level corruption)
- A 5-second timeout wraps each parse to catch infinite loops.

## Pattern

```ruby
# spec/emf/corrupted_resilience_spec.rb
RSpec.describe "corrupted EMF resilience" do
  Dir.glob("spec/fixtures/emf-corrupted/*.emf").each do |path|
    it "does not crash or hang on #{File.basename(path)}" do
      bytes = File.read(path, mode: "rb")
      outcome = Timeout.timeout(5) do
        begin
          mf = Emf.parse(bytes)
          :parsed
        rescue Emf::FormatError
          :format_error
        end
      end rescue :timeout

      expect(outcome).not_to eq(:timeout), "parser hung on #{File.basename(path)}"
      expect(%i[parsed format_error]).to include(outcome)
    end
  end
end
```

## Mapping to README

The `spec/fixtures/emf-corrupted/README.md` (already present in the repo) documents each file. Cross-reference its claims against the actual outcome — e.g., if README says "EMF+ Size field corrupted", the parser should report a parse error on that record. Add per-file expectations where the README is specific.

## Done when

- [ ] All 21 corrupted fixtures parse without unhandled exceptions or hangs.
- [ ] Each file produces either a `Metafile` with errors or a `FormatError`.
- [ ] Spec is parameterised (one example per file via `Dir.glob`).
- [ ] Timeout covers hangs.
