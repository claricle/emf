# TODO 18 — Visitors: `Dump` and `Stats`

**Priority:** P1
**Depends on:** 15
**Status:** pending

## Context

A `Visitor` walks the record tree and produces some output. We need two:

- `Emf::Visitors::Stats` — produces a histogram of record types. Used by spec assertions (TODO 16) and as a quick sanity check.
- `Emf::Visitors::Dump` — produces a human-readable indented dump. Used by the CLI (TODO 19) and as a debugging tool.

Both subclass `Emf::Model::Visitor` (TODO 05) and override the `visit_*` methods they care about.

## Outcomes

- `Emf::Visitors::Stats` has:
  - `#visit(record)` — increments a counter for the record's class name.
  - `#histogram` — returns `{ "Emf::Model::Emf::Records::Polygon" => 12, ... }`.
  - `#to_s` — pretty-prints the histogram.
- `Emf::Visitors::Dump` has:
  - `#visit(record)` — appends a formatted line for each record.
  - `#to_s` — returns the full dump string.
  - Indentation for nested records (e.g. EMF+ inside EMF Comment).

## Pattern

```ruby
# lib/emf/visitors/stats.rb
module Emf
  module Visitors
    class Stats < Emf::Model::Visitor
      def initialize
        @counts = Hash.new(0)
      end

      def visit(record)
        @counts[record.class.name] += 1
      end

      def histogram
        @counts.sort.to_h
      end

      def visit_all(metafile)
        metafile.each { |r| visit(r) }
        if metafile.emf_plus.is_a?(Emf::Model::Metafile)
          metafile.emf_plus.each { |r| visit(r) }
        end
        self
      end

      def to_s
        histogram.map { |k, v| "#{v.to_s.rjust(6)}  #{k}" }.join("\n")
      end
    end
  end
end
```

Note: since the base Visitor auto-registers `visit_*` methods as no-ops (TODO 05), `Stats` overrides only the base `visit(record)` (which the record's `accept` doesn't call — the record calls `visit_<type>`). Hmm, this is a problem.

Let me reconcile. Each record's `accept` calls `visitor.visit_emf_polygon(self)` etc. So `Stats` should override `method_missing` OR override every `visit_*` method.

Per the rules: no `respond_to?` for typing. But `method_missing` is fine (it's not for typing, it's for absorption).

Better: have `Stats` redefine every `visit_*` to increment. Use the same registry-driven mechanism:

```ruby
class Stats < Emf::Model::Visitor
  Emf::Model::Visitor.visit_methods.each do |name|
    define_method(name) { |record| tally(record) }
  end

  def initialize
    @counts = Hash.new(0)
  end

  private

  def tally(record)
    @counts[record.class.name] += 1
  end
end
```

But this requires `visit_methods` to be populated before `Stats` loads — which requires all record types to be loaded first. Solution: lazy-define on first `visit` call, or eager-load records when `Stats` is first instantiated.

Cleaner: use the auto-registration mechanism in reverse. When `Stats` is loaded, it iterates the registered visit methods and installs a default handler.

Actually simplest: redefine the base `Visitor#visit` to also accept "default" calls, and have each record's `accept` call `visitor.visit(self)` rather than `visitor.visit_emf_polygon(self)`. The base `visit` dispatches via `case` on the class. But that's the switch-statement anti-pattern.

OK let's commit to: each record's `accept` calls `visitor.visit_<name>(self)`. Each consumer that wants generic handling (Stats, Dump) installs methods via `define_method` over the registered set. The base `Visitor` provides no-op defaults for any `visit_*` not explicitly overridden.

```ruby
# lib/emf/model/visitor.rb (revised)
module Emf
  module Model
    class Visitor
      @visit_methods = Set.new

      class << self
        attr_reader :visit_methods

        def register_visit(name)
          @visit_methods << name
          return if method_defined?(name)
          define_method(name) { |*| nil }
        end

        def for_all_records(&block)
          @visit_methods.each do |name|
            define_method(name, &block) unless method_defined?(name) && instance_method(name).owner != self
          end
        end
      end
    end
  end
end
```

Then `Stats` calls `Emf::Model::Visitor.for_all_records { |record| tally(record) }` at class-load time, requiring all records to be loaded first.

Hmm, this creates a load-order dependency. The cleanest solution: Stats defines `method_missing` as a no-op:

```ruby
class Stats < Emf::Model::Visitor
  def initialize
    @counts = Hash.new(0)
  end

  def visit(record)
    record.accept(self)
    self
  end

  def method_missing(name, *args)
    return super unless name.to_s.start_with?("visit_")
    tally(args.first) if args.first
  end

  def respond_to_missing?(name, include_private = false)
    name.to_s.start_with?("visit_") || super
  end
  # ...
end
```

Wait — `respond_to?` is forbidden by the rules. But `respond_to_missing?` is different — it's the framework hook Ruby's runtime calls to know if method_missing will handle a symbol. This is legitimate, not type-checking.

The rule says "NEVER use `respond_to?` for type checking." `respond_to_missing?` is a meta-hook to inform Ruby that method_missing will handle certain symbols. This is not type-checking. It IS allowed (Ruby's stdlib uses it everywhere).

OK so `Stats` and `Dump` can use `method_missing` + `respond_to_missing?` to absorb any `visit_*` not explicitly overridden. The base `Visitor` provides no-op defaults for everything via auto-registration.

Actually — the base Visitor already provides no-ops via `register_visit`. So subclasses can just NOT override and rely on the no-op. Stats needs to override EVERY visit_*, which is the challenge.

Final decision: **`Stats` and `Dump` use `method_missing` + `respond_to_missing?`** to absorb all `visit_*` calls generically. Other visitors (emfsvg's, the future SVG emitter) override specific `visit_*` methods and rely on the base no-op for the rest.

## Files

```
lib/emf/visitors.rb                  # namespace autoload
lib/emf/visitors/stats.rb
lib/emf/visitors/dump.rb
spec/emf/visitors/stats_spec.rb
spec/emf/visitors/dump_spec.rb
```

## Verification

```ruby
RSpec.describe Emf::Visitors::Stats do
  it "counts records by class name" do
    mf = Emf.parse_file("spec/fixtures/simple/image1.emf")
    stats = described_class.new
    mf.each { |r| stats.visit(r) }
    expect(stats.histogram).not_to be_empty
  end
end
```

## Done when

- [ ] `Stats` produces a histogram for every fixture.
- [ ] `Dump` produces a readable dump.
- [ ] Both handle EMF+ nested metafiles.
- [ ] No `respond_to?` for typing (but `respond_to_missing?` is OK — it's a runtime meta-hook, not type checking).
