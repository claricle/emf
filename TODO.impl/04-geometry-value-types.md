# TODO 04 — Geometry value types (Point / Size / Rect / Color / Matrix)

**Priority:** P0
**Depends on:** 03
**Status:** pending

## Context

The wire layer (bindata) gives us byte-faithful structs. The domain layer needs semantic value objects: a `Point` is a logical concept, not just a struct with x and y integers. These value types:

- Are immutable (constructed once, never mutated).
- Have value equality (two `Point.new(1, 2)` are `==`).
- Have `from_wire`/`to_wire` translators to/from bindata records.
- Carry no behaviour beyond what is intrinsic (arithmetic on points is for emfsvg, not emf).

## Outcomes

- `lib/emf/model/geometry.rb` defines the value types below.
- Each type is `Value` semantics (include `Comparable` where natural, define `==`, `eql?`, `hash`).
- Each type has `from_wire(wire_record)` and `#to_wire` returning a bindata record.
- Construction via keyword args: `Emf::Model::Geometry::Point.new(x: 10, y: 20)`.
- Specs cover equality, hashing (for use as Hash keys), and round-trip via wire.

## Value types to declare

All under `Emf::Model::Geometry`.

| Type | Attributes | Wire translation |
|---|---|---|
| `Point` | `x` (Integer), `y` (Integer) | `Binary::Types::PointL` |
| `PointF` | `x` (Float), `y` (Float) | `Binary::Types::PointD` |
| `PointS` | `x` (Integer), `y` (Integer) | `Binary::Types::PointS` |
| `Size` | `cx` (Integer), `cy` (Integer) | `Binary::Types::SizeL` |
| `Rect` | `left`, `top`, `right`, `bottom` (Integer) | `Binary::Types::RectL` |
| `RectS` | `left`, `top`, `right`, `bottom` (Integer) | `Binary::Types::RectS` |
| `Color` | `red`, `green`, `blue` (0..255), `alpha` (0..255, default 255) | `Binary::Types::ColorRef` (alpha lives in `reserved` byte) |
| `Matrix` | `m11`, `m12`, `m21`, `m22`, `dx`, `dy` (Float) | `Binary::Types::XForm` |

## Helpers (only intrinsic behaviour)

- `Color#to_hex` → `"#RRGGBB"` (alpha omitted if 255)
- `Color#to_hex_rgba` → `"#RRGGBBAA"`
- `Color.black`, `Color.white`, `Color.transparent` constructors
- `Rect#width`, `Rect#height`, `Rect#contains?(point)`, `Rect#empty?`
- `Point#translate(dx, dy)` → new Point
- `Matrix#identity?`, `Matrix.identity`

No rotate/scale/invert — that's emfsvg's concern.

## Patterns

```ruby
# lib/emf/model/geometry.rb
module Emf
  module Model
    module Geometry
      class Point
        attr_reader :x, :y

        def initialize(x:, y:)
          @x = x
          @y = y
        end

        def self.from_wire(wire)
          new(x: wire.x, y: wire.y)
        end

        def to_wire
          Binary::Types::PointL.new(x: x, y: y)
        end

        def translate(dx, dy)
          Point.new(x: x + dx, y: y + dy)
        end

        def ==(other)
          other.is_a?(Point) && x == other.x && y == other.y
        end
        alias eql? ==

        def hash
          [x, y].hash
        end
      end
    end
  end
end
```

Use `autoload` for each class from `lib/emf/model/geometry.rb`:

```ruby
# lib/emf/model/geometry.rb
module Emf
  module Model
    module Geometry
      autoload :Point, "emf/model/geometry/point"
      autoload :PointF, "emf/model/geometry/point_f"
      autoload :PointS, "emf/model/geometry/point_s"
      autoload :Size, "emf/model/geometry/size"
      autoload :Rect, "emf/model/geometry/rect"
      autoload :RectS, "emf/model/geometry/rect_s"
      autoload :Color, "emf/model/geometry/color"
      autoload :Matrix, "emf/model/geometry/matrix"
    end
  end
end
```

So each value type lives in its own file: `lib/emf/model/geometry/point.rb`, etc. This keeps files small and the namespace clean.

## Verification

```ruby
RSpec.describe Emf::Model::Geometry::Color do
  it "round-trips via wire" do
    color = described_class.new(red: 0xFF, green: 0x80, blue: 0x00)
    wire = color.to_wire
    expect(wire.red).to eq(255)
    expect(wire.green).to eq(128)
    expect(wire.blue).to eq(0)
    expect(described_class.from_wire(wire)).to eq(color)
  end

  it "renders hex" do
    color = described_class.new(red: 0xFF, green: 0x80, blue: 0x00)
    expect(color.to_hex).to eq("#FF8000")
  end

  it "has value equality" do
    a = described_class.new(red: 1, green: 2, blue: 3)
    b = described_class.new(red: 1, green: 2, blue: 3)
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end
end
```

## Done when

- [ ] All 8 value types declared.
- [ ] Each has `from_wire`, `to_wire`, value equality, hash.
- [ ] Color has helpers (`to_hex`, `to_hex_rgba`, presets).
- [ ] Rect has helpers (`width`, `height`, `contains?`, `empty?`).
- [ ] Matrix has `identity?` and `identity`.
- [ ] Specs all green.
- [ ] No doubles, no `respond_to?` for typing, no `instance_variable_set/get`.
