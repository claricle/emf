# frozen_string_literal: true

# Reference for Records::WireAdapter.build: the BinData construction the
# factory must be indistinguishable from, `klass.new(**attrs)` with n_size set
# to num_bytes, wrapped in a plain adapter, which is what callers did before.
module WireBuildOracle
  ADAPTER = Emf::Model::Emr::Records::WireAdapter
  RECORDS = Emf::Emr::Binary::Records
  FILL = Emf::Emr::Binary::FastFill
  BINDATA_WRITER = BinData::Base.instance_method(:to_binary_s)

  LEAF_POOLS = {
    "BinData::Uint32le" => [0, 1, 2, 37, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF, 0x1_0000_0000, -1, 2**70],
    "BinData::Int32le" => [0, 1, -1, 0x7FFF_FFFF, -0x8000_0000, 0x8000_0000, -0x8000_0001, 2**40, -(2**40)],
    "BinData::Uint8" => [0, 1, 127, 255, 256, -1, 1000],
    "BinData::Rest" => ["", "abc".b, "\xFF".b * 9, "\u00E9", "A\x00B\x00".b, 7],
    "BinData::Int16le" => [0, 1, -1, 0x7FFF, -0x8000, 0x8000, -0x8001],
    "Emf::Binary::Float32Le" => [0.0, -0.0, 1.0, -2.5, 3, -7, 1e-45, 3.4028235e38, 1e39, 1e300, 1e-60,
                                 Float::INFINITY, -Float::INFINITY, Float::NAN, 16_777_217, 2**70]
  }.freeze
  SMALL_COUNTS = [0, 1, 2, 3, 9, 40, 41].freeze
  WRONG = [nil, "7", "", 1.5, 2.0, true, false, :sym, [], {}, [1], (1..2)].freeze

  module_function

  def classes
    RECORDS.constants.map { |name| RECORDS.const_get(name) }.select { |c| c.is_a?(Class) && c < BinData::Base }
  end

  def filled_classes
    classes.select { |klass| FILL.for_class(klass) }
  end

  # [error class, message] or the value; an error at any step is the outcome.
  def outcome
    [:ok, yield]
  rescue StandardError => e
    [:error, e.class, e.message]
  end

  def reference(klass, attrs)
    wire = klass.new(**attrs)
    wire.n_size = wire.num_bytes
    ADAPTER.new(wire: wire)
  end

  def built(klass, attrs)
    ADAPTER.build(klass, **attrs)
  end

  # A fully instantiated sample: field name => leaf class name, or a nested
  # Hash of them, or :array for a point array.
  def shape(struct)
    struct.field_names.to_h do |name|
      field = struct.public_send(name)
      kind = if field.is_a?(BinData::Array) then :array
             elsif field.respond_to?(:field_names) then shape(field)
             else field.class.name
             end
      [name, kind]
    end
  end

  def leaf_paths(shape, prefix = [])
    shape.flat_map do |name, kind|
      kind.is_a?(Hash) ? leaf_paths(kind, prefix + [name]) : [[prefix + [name], kind]]
    end
  end

  # Distinct valid values (seed varies them) for every field, point arrays included.
  def full_attrs(klass, seed = 1)
    sample = klass.new
    index = 0
    fill = lambda do |node|
      node.to_h do |name, kind|
        index += 1
        value = case kind
                when Hash then fill.call(kind)
                when :array then [{ x: seed + index, y: -index }, { x: -seed, y: index * 3 }]
                else in_range_value(kind, seed + index)
                end
        [name, value]
      end
    end
    attrs = fill.call(shape(sample)).except(:n_size)
    array, count = point_names(klass)
    count ? attrs.merge(count => attrs.fetch(array).size) : attrs
  end

  # [array field, count field] of a point array record, else nil.
  def point_names(klass)
    sample = klass.new
    array = sample.field_names.find { |name| sample.public_send(name).is_a?(BinData::Array) }
    array && [array, sample.public_send(array).send(:get_parameter, :initial_length)]
  end

  def planned_classes
    filled_classes.select { |klass| FILL.for_class(klass).pack_plan }
  end

  def in_range_value(kind, number)
    case kind
    when "BinData::Uint8" then number % 256
    when "Emf::Binary::Float32Le" then number + 0.25
    when "BinData::Int32le" then number * 7919 * (number.odd? ? -1 : 1)
    else number * 100_003
    end
  end

  # One random attribute hash for the class: random subset of its fields, each
  # from a pool of valid, boundary, out-of-range and wrong-typed values.
  def random_attrs(klass, random)
    node = shape(klass.new)
    count_name = point_names(klass)&.last
    attrs = {}
    node.each do |name, kind|
      next unless random.rand < 0.6

      # A huge count makes BinData itself allocate that many elements.
      attrs[name] = name == count_name ? SMALL_COUNTS.sample(random: random) : random_value(kind, random)
    end
    attrs[[:bogus, "bogus", :i_type].sample(random: random)] = 1 if random.rand < 0.08
    attrs
  end

  def random_value(kind, random)
    return WRONG.sample(random: random) if random.rand < 0.06

    case kind
    when Hash then random_struct(kind, random)
    when :array then random_points(random)
    else LEAF_POOLS.fetch(kind).sample(random: random)
    end
  end

  def random_struct(node, random)
    case random.rand(10)
    when 0 then node.keys.sample(random: random)
    when 1 then { bogus: 1 }
    else
      node.select { random.rand < 0.7 }.to_h { |name, kind| [name, random_value(kind, random)] }
    end
  end

  def random_points(random)
    count = [0, 1, 2, 3, 9, 40].sample(random: random)
    Array.new(count) do
      case random.rand(12)
      when 0 then { x: 1 }
      when 1 then { x: 1, y: 2, z: 3 }
      when 2 then [1, 2]
      when 3 then { "x" => 1, "y" => 2 }
      when 4 then { x: 1.5, y: 2 }
      else { x: LEAF_POOLS["BinData::Int32le"].sample(random: random), y: LEAF_POOLS["BinData::Int16le"].sample(random: random) }
      end
    end
  end

  # What a caller can observe of an adapter without touching its wire: bytes
  # (twice, each a distinct String), hash, type id and the size field.
  def unwired_view(adapter)
    first = adapter.to_binary_s
    [first, adapter.to_binary_s, first.encoding, adapter.hash, adapter.type_id, adapter.offset]
  end

  # Everything observable on the wire of an adapter.
  def wire_view(adapter)
    wire = adapter.wire
    [wire.class, wire.snapshot, wire.num_bytes, wire.to_binary_s, BINDATA_WRITER.bind_call(wire), wire.field_names,
     wire.frozen?, adapter.suffix, adapter.to_binary_s, adapter.inspect]
  end

  # Parent of every field object, as a path of field names to the wire.
  def parent_links(wire)
    wire.field_names.flat_map do |name|
      field = wire.public_send(name)
      link = [name, field.parent.equal?(wire)]
      field.respond_to?(:field_names) ? [link, *nested_links(field)] : [link]
    end
  end

  def nested_links(struct)
    struct.field_names.map { |name| [name, struct.public_send(name).parent.equal?(struct)] }
  end
end

# Example helpers: one factory-versus-reference comparison per call.
module WireBuildExpectations
  def expect_same_bytes(klass, attrs)
    expect(WireBuildOracle.outcome { WireBuildOracle.built(klass, attrs).to_binary_s })
      .to eq(WireBuildOracle.outcome { WireBuildOracle.reference(klass, attrs).to_binary_s })
  end

  def expect_same_wire(klass, attrs)
    expect(WireBuildOracle.outcome { WireBuildOracle.wire_view(WireBuildOracle.built(klass, attrs)) })
      .to eq(WireBuildOracle.outcome { WireBuildOracle.wire_view(WireBuildOracle.reference(klass, attrs)) })
  end

  def expect_same_snapshot(klass, attrs)
    expect(WireBuildOracle.outcome { WireBuildOracle.built(klass, attrs).wire.snapshot.to_s })
      .to eq(WireBuildOracle.outcome { WireBuildOracle.reference(klass, attrs).wire.snapshot.to_s })
  end
end
