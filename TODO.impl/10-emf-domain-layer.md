# TODO 10 — EMF domain layer

**Priority:** P0
**Depends on:** 04, 09
**Status:** pending

## Context

The wire layer (TODO 09) gives us byte-faithful bindata records. The domain layer translates them into semantic OOP value objects: a `Polygon` is "a closed shape with N points", not "a record with cptl and aptl fields". The domain layer is what emfsvg consumes.

## Outcomes

- One domain class per EMR_* record type, mirroring TODO 09's wire classes.
- Each domain class:
  - Inherits from `Emf::Model::Record` (TODO 05).
  - Has `attr_reader` for semantic fields.
  - Has `.from_wire(wire)` class method.
  - Has `#to_wire` instance method returning the bindata record.
  - Has `#accept(visitor)` calling the right `visit_*` method.
  - Has value equality.
- `Emf::Model::Emf::Header` wraps the wire header with semantic helpers (`#bounds`, `#frame`, `#device_pixels`, `#device_mm`, `#description`, `#version`).

## Naming

Wire: `Emf::Emf::Binary::Records::Polygon16`
Domain: `Emf::Model::Emf::Records::Polygon16`

The `Emf::Model::Emf` repetition is intentional (parallels `Emf::Model::Wmf`).

## Pattern

```ruby
# lib/emf/model/emf/records/polygon.rb
module Emf
  module Model
    module Emf
      module Records
        class Polygon < Emf::Model::Record
          Emf::Model::Visitor.register_visit(:visit_emf_polygon)

          TYPE_ID = 3

          def initialize(bounds:, points:)
            @bounds = bounds
            @points = points.freeze
          end

          attr_reader :bounds, :points

          def type_id = TYPE_ID

          def self.from_wire(wire)
            new(
              bounds: Geometry::Rect.from_wire(wire.rclBounds),
              points: wire.aptl.to_a.map { |p| Geometry::Point.from_wire(p) }
            )
          end

          def to_wire
            Emf::Emf::Binary::Records::Polygon.new(
              iType: TYPE_ID,
              nSize: 24 + points.size * 8,
              rclBounds: bounds.to_wire,
              cptl: points.size,
              aptl: points.map(&:to_wire)
            )
          end

          def accept(visitor)
            visitor.visit_emf_polygon(self)
          end

          def ==(other)
            other.is_a?(self.class) && bounds == other.bounds && points == other.points
          end
          alias eql? ==

          def hash
            [self.class, bounds, points].hash
          end
        end
      end
    end
  end
end
```

## Header domain

```ruby
# lib/emf/model/emf/header.rb
module Emf
  module Model
    module Emf
      class Header
        def initialize(bounds:, frame:, signature:, version:, device_pixels:, device_mm:, description: nil)
          @bounds = bounds
          @frame = frame
          @signature = signature
          @version = version
          @device_pixels = device_pixels
          @device_mm = device_mm
          @description = description
        end

        attr_reader :bounds, :frame, :signature, :version, :device_pixels, :device_mm, :description

        def self.from_wire(wire)
          new(
            bounds: Geometry::Rect.from_wire(wire.rclBounds),
            frame: Geometry::Rect.from_wire(wire.rclFrame),
            signature: wire.dSignature,
            version: wire.nVersion,
            device_pixels: Geometry::Size.from_wire(wire.szlDevice),
            device_mm: Geometry::Size.from_wire(wire.szlMillimeters),
            description: wire.description.to_s
          )
        end
      end
    end
  end
end
```

## Files

Mirror of TODO 09:
```
lib/emf/model/emf.rb
lib/emf/model/emf/header.rb
lib/emf/model/emf/records.rb               # namespace + autoload
lib/emf/model/emf/records/*.rb             # ~100 domain classes
spec/emf/model/emf/records/*_spec.rb       # per-record from_wire/to_wire
```

## Reducing boilerplate

Some records share structure (POLYGON vs POLYGON16 differ only in point type). To stay DRY, define a `Emf::Model::Emf::Records::PolygonLike` module included by both, with shared `accept` and equality methods. The actual `points`/`from_wire`/`to_wire` differ and stay in each class.

For records with NO payload (e.g. `EMR_EOF`, `EMR_SAVEDC`, `EMR_BEGINPATH`, `EMR_CLOSEFIGURE`), define a `Emf::Model::Emf::Records::Control` base class they inherit from with no fields.

## Verification

For each domain record:
1. Construct via `from_wire(wire)` from a known wire instance.
2. Assert fields.
3. Call `to_wire` and assert byte-equality with original.
4. Assert equality semantics.

```ruby
RSpec.describe Emf::Model::Emf::Records::Polygon do
  let(:wire) do
    Emf::Emf::Binary::Records::Polygon.read(
      [3, 24, 0, 0, 0, 0, 100, 0, 0, 0, 100, 0, 0, 0, 1, 10, 0, 0, 0, 20, 0, 0, 0].pack("V*")
    )
  end

  it "translates wire to domain" do
    domain = described_class.from_wire(wire)
    expect(domain.bounds.right).to eq(100)
    expect(domain.points.first.x).to eq(10)
    expect(domain.type_id).to eq(3)
  end

  it "round-trips back to wire" do
    domain = described_class.from_wire(wire)
    expect(domain.to_wire.to_binary_s).to eq(wire.to_binary_s)
  end

  it "visits as a polygon" do
    visitor = Class.new(Emf::Model::Visitor) do
      attr_accessor :visited
      def visit_emf_polygon(record) = (@visited ||= []) << record
    end.new
    described_class.from_wire(wire).accept(visitor)
    expect(visitor.visited.length).to eq(1)
  end
end
```

## Done when

- [ ] All ~100 EMR_* record types have a domain class.
- [ ] `Emf::Model::Emf::Header` exposes semantic fields.
- [ ] All from_wire / to_wire round-trip.
- [ ] All visit_* methods are registered with `Emf::Model::Visitor.register_visit`.
- [ ] All specs green.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing.
