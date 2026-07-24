# TODO 05 — Metafile container, Record base, Visitor base

**Priority:** P0
**Depends on:** 04
**Status:** pending

## Context

The `Metafile` is the top-level product of every parser: it holds the header (format-specific), the ordered list of domain records, and the list of parse errors. The `Record` base class establishes the contract every domain record honours: `accept(visitor)` for double-dispatch. The `Visitor` base class is the "no-op default" that consumers subclass.

These three together form the spine of the public model. emfsvg will subclass `Emf::Model::Visitor` to walk records; `Emf::Visitors::Dump` (TODO 18) and `Emf::Visitors::Stats` (TODO 18) are emf's own subclasses for debugging and spec assertions.

## Outcomes

- `lib/emf/model/metafile.rb` defines `Emf::Model::Metafile`, an immutable container with:
  - `format` (`:wmf`, `:emf`, or `:emf_plus` — the latter when the EMF also carried an EMF+ stream)
  - `header` (format-specific header object — `Emf::Model::Wmf::Header`, `Emf::Model::Emf::Header`, etc.)
  - `records` (frozen Array of `Emf::Model::Record` subclasses)
  - `errors` (frozen Array of `Emf::ParseError`)
  - `emf_plus` (optional nested `Metafile` if the source EMF carried an EMF+ stream — `nil` otherwise)
  - constructed via `Metafile.new(format:, header:, records:, errors: [], emf_plus: nil)`
  - `#each_record(&block)` and `Enumerable` mixin
  - `#has_errors?` and `#ok?` (inverse)
- `lib/emf/model/record.rb` defines `Emf::Model::Record` as an **abstract** base class:
  - Subclasses must implement `accept(visitor)` and `type_id` (Integer).
  - Base provides a default `inspect` showing class + key fields (override-friendly).
- `lib/emf/model/visitor.rb` defines `Emf::Model::Visitor`:
  - `visit(record)` dispatches via `record.accept(self)` (so visitors override `visit_<record_type>` methods; the default `method_missing`-free dispatcher raises a clear error if no handler is defined).
  - Wait — no `respond_to?` for dispatch. Instead: use a case statement in `accept` on the record class OR use a registered handler hash. **Decision: each record class implements `accept(visitor)` directly calling `visitor.visit_polygon(self)` etc.** The base `Visitor` defines every `visit_*` as a no-op (returns `nil`). Subclasses override the ones they care about. This is plain method dispatch, no metaprogramming.

## Visitor pattern (concrete design)

```ruby
# lib/emf/model/visitor.rb
module Emf
  module Model
    class Visitor
      # Default: no-op for every record type. Subclasses override what they need.
      def visit_header(record) = nil
      def visit_eof(record) = nil
      def visit_polygon(record) = nil
      def visit_polyline(record) = nil
      # ... one method per domain record type, across all three formats.
      # This file is the canonical list. Adding a record means adding a method here
      # AND a visit_<name> override wherever needed.
    end
  end
end
```

Hmm — that violates OCP (modify the base when adding records). Better:

```ruby
# lib/emf/model/visitor.rb
module Emf
  module Model
    class Visitor
      def visit(record)
        record.accept(self)
      end

      # Default catch-all: each record's `accept` calls a specific method on visitor.
      # If visitor doesn't override, method_missing here provides a no-op fallback
      # that's STILL not relying on respond_to? — it just absorbs unknown methods.
      # We DO NOT use method_missing; instead, each record's accept uses a stable
      # method name, and Visitor base defines them all as no-ops via a registration
      # mechanism at load time.
    end
  end
end
```

Cleaner pattern: **no catch-all**. Each record class hard-codes its visit method name. The Visitor base provides no-op defaults for every method name **via a registry-driven generator at load time**:

```ruby
# lib/emf/model/visitor.rb
module Emf
  module Model
    class Visitor
      # The set of visit_* method names is registered by record classes themselves.
      @visit_methods = []

      class << self
        attr_reader :visit_methods

        def register_visit(name)
          @visit_methods << name
          attr_reader name unless method_defined?(name)
          define_method(name) { |*| nil } unless method_defined?(name, true)
        end
      end

      def visit(record)
        record.accept(self)
      end
    end
  end
end
```

Each record file:
```ruby
class Polygon < Record
  Visitor.register_visit(:visit_polygon)

  def accept(visitor)
    visitor.visit_polygon(self)
  end
end
```

This is OCP-clean: adding a record = adding one line in the record's own file. The Visitor base picks up the method automatically. Subclasses override only what they need.

## Metafile container

```ruby
# lib/emf/model/metafile.rb
module Emf
  module Model
    class Metafile
      include Enumerable

      def initialize(format:, header:, records:, errors: [], emf_plus: nil)
        @format = format
        @header = header
        @records = records.freeze
        @errors = errors.freeze
        @emf_plus = emf_plus
      end

      attr_reader :format, :header, :records, :errors, :emf_plus

      def each(&block)
        @records.each(&block)
      end

      def has_errors? = !@errors.empty?
      def ok? = @errors.empty?
    end
  end
end
```

## Record base

```ruby
# lib/emf/model/record.rb
module Emf
  module Model
    class Record
      def type_id
        raise NotImplementedError, "subclass must return the integer record type code"
      end

      def accept(visitor)
        raise NotImplementedError, "subclass must implement #accept(visitor)"
      end

      def inspect
        "#<#{self.class.name} type_id=#{type_id}>"
      end
    end
  end
end
```

## Files

```
lib/emf/model/metafile.rb
lib/emf/model/record.rb
lib/emf/model/visitor.rb
spec/emf/model/metafile_spec.rb
spec/emf/model/record_spec.rb
spec/emf/model/visitor_spec.rb
```

## Verification

```ruby
RSpec.describe Emf::Model::Metafile do
  it "freezes records and errors" do
    mf = described_class.new(format: :emf, header: :fake, records: [])
    expect(mf.records).to be_frozen
    expect(mf.errors).to be_frozen
  end

  it "knows when it has errors" do
    ok = described_class.new(format: :emf, header: nil, records: [])
    bad = described_class.new(format: :emf, header: nil, records: [], errors: [Emf::ParseError.new(offset: 0, record_code: 99, message: "x")])
    expect(ok.ok?).to be true
    expect(bad.has_errors?).to be true
  end
end

RSpec.describe Emf::Model::Visitor do
  it "auto-registers visit methods from records" do
    stub_record = Class.new(Emf::Model::Record) do
      Emf::Model::Visitor.register_visit(:visit_stub)
      def accept(visitor) = visitor.visit_stub(self)
    end
    v = Emf::Model::Visitor.new
    expect(v.visit(stub_record.new)).to be_nil   # no-op default
  end
end
```

## Done when

- [ ] `Metafile` immutable container, Enumerable, has `ok?`/`has_errors?`.
- [ ] `Record` abstract base with `type_id` and `accept` contracts.
- [ ] `Visitor` with auto-registration via `register_visit`.
- [ ] All specs green.
- [ ] No doubles, no `respond_to?` for dispatch, no `instance_variable_set/get`.
