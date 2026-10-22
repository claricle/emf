# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/wire_build_oracle"

# Equivalence oracle for Records::WireAdapter.build: for every wire record
# class, a factory-built adapter is indistinguishable from the one made by
# `klass.new(**attrs)`, n_size = num_bytes, WireAdapter.new(wire:). The factory
# serves bytes until `#wire` is called and the wire afterwards.
RSpec.describe Emf::Model::Emr::Records::WireAdapter, ".build" do
  include WireBuildExpectations

  oracle = WireBuildOracle
  all_classes = oracle.classes
  filled = oracle.filled_classes

  short = ->(klass) { klass.name.split("::").last }

  it "covers every wire record class, filled and not" do
    expect(all_classes.size).to be >= 119
    expect(filled.size).to eq(49)
    expect(oracle.planned_classes.size).to eq(47)
  end

  it "is additive: building records with new is unchanged" do
    klass = Emf::Emr::Binary::Records::SelectObject
    expect(klass.new(i_type: 37, ih_object: 3).to_binary_s).to eq([37, 12, 3].pack("V3").tap { |b| b[4, 4] = [0].pack("V") })
  end

  describe "classes without a plan" do
    (all_classes - filled).each do |klass|
      it "#{short.call(klass)} builds the adapter klass.new would" do
        attrs = { i_type: 5 }
        [attrs, {}].each do |given|
          expect_same_bytes(klass, given)
          expect_same_wire(klass, given)
        end
      end
    end
  end

  describe "equivalence for each class with full attributes" do
    oracle.planned_classes.each do |klass|
      context short.call(klass) do
        let(:attrs) { oracle.full_attrs(klass) }
        let(:other_attrs) { oracle.full_attrs(klass, 11) }
        let(:factory) { oracle.built(klass, attrs) }
        let(:reference) { oracle.reference(klass, attrs) }

        it "serializes the same bytes, as a fresh binary String each time, before the wire exists" do
          expect(oracle.unwired_view(factory)).to eq(oracle.unwired_view(reference))
          expect(factory.to_binary_s).not_to equal(factory.to_binary_s)
          expect(factory.to_binary_s).not_to be_frozen
          expect(factory.to_binary_s[4, 4].unpack1("V")).to eq(factory.to_binary_s.bytesize)
        end

        it "matches plain BinData bytes where BinData accepts the attributes" do
          wire = klass.new(attrs.dup)
          wire.n_size = wire.num_bytes
          expect(factory.to_binary_s).to eq(oracle::BINDATA_WRITER.bind_call(wire))
        end

        it "materializes a wire equal in every observable, and serializes the same afterwards" do
          bytes = factory.to_binary_s
          expect(oracle.wire_view(factory)).to eq(oracle.wire_view(reference))
          expect(factory.to_binary_s).to eq(bytes)
        end

        it "equals, hashes and inspects like the reference, either side of #wire" do
          expect(factory).to eq(reference)
          expect(factory.eql?(reference)).to be(true)
          expect(factory.hash).to eq(reference.hash)
          expect(reference).to eq(factory)
          expect(factory.inspect).to eq(reference.inspect)
          factory.wire
          expect(factory).to eq(reference)
          expect(factory.hash).to eq(reference.hash)
        end

        it "returns the same wire object and the same field objects on repeated reads" do
          wire = factory.wire
          expect(factory.wire).to equal(wire)
          first = wire.field_names.first
          expect(wire.public_send(first)).to equal(wire.public_send(first))
          expect(oracle.parent_links(wire)).to eq(oracle.parent_links(reference.wire))
        end

        it "serializes a nested-field mutation of the wire" do
          path, = oracle.leaf_paths(oracle.shape(klass.new)).reject { |p, kind| p == [:n_size] || kind == :array }.last
          [factory, reference].each do |adapter|
            path.inject(adapter.wire) { |node, name| node.public_send(name) }.assign(42)
          end
          expect(factory.to_binary_s).to eq(reference.to_binary_s)
        end

        it "serializes a top-level assignment and a whole-struct assignment to the wire" do
          other = oracle.reference(klass, other_attrs)
          [factory, reference].each { |adapter| adapter.wire.assign(other.wire) }
          expect(factory.to_binary_s).to eq(reference.to_binary_s)
          expect(factory.to_binary_s).to eq(other.to_binary_s)
        end

        it "round-trips through read, with trailing bytes ignored and truncation raising alike" do
          bytes = factory.to_binary_s
          expect(klass.read(bytes).snapshot).to eq(reference.wire.snapshot)
          expect(klass.read(bytes + "\x01\x02".b).snapshot).to eq(reference.wire.snapshot)
          cut = bytes.byteslice(0, bytes.bytesize - 1)
          expect(oracle.outcome { klass.read(cut) }).to eq(oracle.outcome {
            klass.read(reference.to_binary_s.byteslice(0, bytes.bytesize - 1))
          })
        end
      end
    end
  end

  describe "the invariant: bytes until #wire, the wire after" do
    let(:klass) { Emf::Emr::Binary::Records::SelectObject }
    let(:adapter) { described_class.build(klass, i_type: 37, ih_object: 5) }

    it "serves the built bytes without making a wire" do
      expect(adapter.instance_variable_get(:@wire)).to be_nil
      adapter.to_binary_s
      adapter.type_id
      adapter.hash
      expect(adapter.instance_variable_get(:@wire)).to be_nil
    end

    it "never serves stale bytes once #wire has been called" do
      adapter.wire.ih_object.assign(9)
      expect(adapter.to_binary_s).to eq(oracle.reference(klass, i_type: 37, ih_object: 9).to_binary_s)
      adapter.wire.ih_object.assign(11)
      expect(adapter.to_binary_s).to eq(oracle.reference(klass, i_type: 37, ih_object: 11).to_binary_s)
    end

    it "serializes a mutation made through a field object fetched before another #to_binary_s" do
      field = adapter.wire.ih_object
      adapter.to_binary_s
      field.assign(77)
      expect(adapter.to_binary_s).to eq(oracle.reference(klass, i_type: 37, ih_object: 77).to_binary_s)
    end

    it "reports a built record's suffix as empty" do
      expect(adapter.suffix).to be_empty
    end
  end

  describe "a class or attribute shape the byte path does not take" do
    let(:klass) { Emf::Emr::Binary::Records::StretchDIBits }

    it "builds the same adapter as before for a class without a filler" do
      attrs = { i_type: 81, x_dest: 1, trailing: "abc".b, rcl_bounds: { left: 1, top: 2, right: 3, bottom: 4 } }
      factory = described_class.build(klass, **attrs)
      expect(factory.instance_variable_get(:@wire)).not_to be_nil
      expect(oracle.wire_view(factory)).to eq(oracle.wire_view(oracle.reference(klass, attrs)))
    end

    it "takes the wire path for a point record given a hash-keyed string, a float or a clamped value" do
      poly = Emf::Emr::Binary::Records::Polygon
      [{ aptl: [{ "x" => 1, "y" => 2 }] }, { aptl: [{ x: 1.5, y: 2 }] }, { aptl: [{ x: 2**40, y: 2 }] }, { cptl: 4 }, { bogus: 1 },
       { rcl_bounds: { left: 2**40 } }, { rcl_bounds: { "left" => 1 } }].each do |attrs|
        expect_same_bytes(poly, attrs)
      end
    end
  end

  describe "point arrays" do
    [Emf::Emr::Binary::Records::Polygon, Emf::Emr::Binary::Records::Polyline16,
     Emf::Emr::Binary::Records::PolyBezierTo, Emf::Emr::Binary::Records::PolylineTo16].each do |klass|
      array, count_field = oracle.point_names(klass)
      counts = [0, 1, 2, 3, 255, 256, 1000]
      name = short.call(klass)
      counts.each do |count|
        it "#{name} with #{count} points, matching and mismatched counts" do
          points = Array.new(count) { |i| { x: (i * 31) - 500, y: 700 - (i * 17) } }
          shorter = [count - 1, 0].max
          [{ array => points, count_field => count }, { array => points }, { array => points, count_field => count + 1 },
           { array => points, count_field => shorter }, { count_field => count }, { array => nil, count_field => 0 }].each do |attrs|
            expect_same_bytes(klass, attrs)
            expect_same_wire(klass, attrs)
          end
        end
      end

      it "#{name} at the coordinate limits and past them" do
        limit = name.end_with?("16") ? 2**15 : 2**31
        [-limit, limit - 1, -limit - 1, limit, 0].each do |value|
          attrs = { array => [{ x: value, y: -value }], count_field => 1 }
          expect_same_bytes(klass, attrs)
          expect_same_wire(klass, attrs)
        end
      end

      it "#{name} with points given as the point class" do
        point = klass.new.public_send(array).send(:new_element).class
        attrs = { array => [point.new(x: 5, y: -6), { x: 7, y: 8 }], count_field => 2 }
        expect(oracle.built(klass, attrs).to_binary_s).to eq(oracle.reference(klass, attrs).to_binary_s)
        expect(oracle.wire_view(oracle.built(klass, attrs))).to eq(oracle.wire_view(oracle.reference(klass, attrs)))
      end
    end
  end

  describe "numeric limits" do
    {
      Emf::Emr::Binary::Records::SelectObject => %i[ih_object],
      Emf::Emr::Binary::Records::SetBkMode => %i[i_mode]
    }.each do |klass, fields|
      fields.each do |field|
        [0, 1, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF, 0x1_0000_0000, -1, -0x8000_0000, 2**70, -(2**70)].each do |value|
          it "#{klass.name.split('::').last}##{field} = #{value}" do
            attrs = { field => value }
            expect_same_bytes(klass, attrs)
          end
        end
      end
    end

    it "matches signed and unsigned limits of rectangle leaves" do
      clip = Emf::Emr::Binary::Records::IntersectClipRect
      [-0x8000_0000, 0x7FFF_FFFF, -0x8000_0001, 0x8000_0000, 0].each do |value|
        attrs = { rcl_clip: { left: value, top: value, right: -value, bottom: value } }
        expect_same_bytes(clip, attrs)
      end
    end

    it "matches byte leaves at 0, 255 and out of range" do
      brush = Emf::Emr::Binary::Records::CreateBrushIndirect
      [0, 255, 256, -1].each do |value|
        attrs = { color: { red: value, green: 255 - value, blue: value, reserved: 0 } }
        expect_same_bytes(brush, attrs)
      end
    end
  end

  describe "float32 leaves" do
    payload_nan = [0x7FC0_0001].pack("V").unpack1("e")
    negative_nan = [0xFFC0_0000].pack("V").unpack1("e")

    [Emf::Emr::Binary::Records::SetWorldTransform, Emf::Emr::Binary::Records::ModifyWorldTransform].each do |klass|
      values = [0.0, -0.0, 1.0, -1.5, Float::INFINITY, -Float::INFINITY, Float::NAN, 1e39, 1e-46, 3, 2**70, payload_nan, negative_nan]
      values.each_with_index do |value, index|
        it "#{klass.name.split('::').last} with #{value.inspect} (case #{index})" do
          attrs = { xform: { m11: value, m22: -value, dx: value } }
          factory = oracle.built(klass, attrs)
          reference = oracle.reference(klass, attrs)
          expect(factory.to_binary_s).to eq(reference.to_binary_s)
          expect(oracle.outcome { factory.wire.snapshot.to_s }).to eq(oracle.outcome { reference.wire.snapshot.to_s })
          expect(factory.to_binary_s).to eq(reference.to_binary_s)
        end
      end
    end

    it "keeps -0.0 and the sign of infinities" do
      klass = Emf::Emr::Binary::Records::SetWorldTransform
      bytes = oracle.built(klass, xform: { m11: -0.0, m12: -Float::INFINITY }).to_binary_s
      expect(bytes[8, 8].unpack("e2")).to eq([-0.0, -Float::INFINITY])
      expect(bytes[8, 4].unpack1("V")).to eq(0x8000_0000)
    end
  end

  describe "text records and padding" do
    let(:klass) { Emf::Emr::Binary::Records::ExtTextOutW }
    options_list = [0, 0x100, 0x2, 0x102]

    [
      "".b, "A".encode("UTF-16LE").b, "Hello, wörld".encode("UTF-16LE").b, "\xFF\xFE\x00".b,
      "x" * 7, "pad".b + ("\x00".b * 5), "\u{1F600}".encode("UTF-16LE").b
    ].each_with_index do |trailing, index|
      options_list.each do |options|
        it "matches with trailing case #{index} and options #{options}" do
          attrs = { f_options: options, trailing: trailing, n_chars: trailing.bytesize / 2, ex_scale: 1.0, ey_scale: -1.0,
                    rcl: { left: 1, top: 2, right: 3, bottom: 4 } }
          factory = oracle.built(klass, attrs)
          reference = oracle.reference(klass, attrs)
          expect(factory.to_binary_s).to eq(reference.to_binary_s)
          expect(oracle.wire_view(factory)).to eq(oracle.wire_view(reference))
        end
      end
    end

    it "matches font and escape records that carry byte bodies" do
      font = Emf::Emr::Binary::Records::CreateFontIndirectW
      ["".b, "a".b, ("w".encode("UTF-16LE") * 32).b, "\x00\xFF".b].each do |body|
        attrs = { ih_object: 2, body: body }
        expect_same_bytes(font, attrs)
      end
    end
  end

  describe "invalid, unknown, nil and wrong-typed attributes" do
    filled.each do |klass|
      it "#{short.call(klass)} raises or builds exactly as klass.new does" do
        sample = oracle.shape(klass.new)
        bad = [{ bogus: 1 }, { "i_type" => 3 }, { n_size: 99 }, { i_type: nil }, { sample.keys.last => nil },
               { sample.keys.first => oracle::WRONG[1] }, { sample.keys.first => 1.5 }]
        bad += oracle::WRONG.map { |value| { sample.keys.last => value } }
        bad.each do |attrs|
          expect_same_bytes(klass, attrs)
          expect_same_snapshot(klass, attrs)
        end
      end
    end

    it "builds with no attributes" do
      filled.each do |klass|
        expect(oracle.built(klass, {}).to_binary_s).to eq(oracle.reference(klass, {}).to_binary_s)
      end
    end

    it "takes a nested struct given as an instance of its class, a Hash, nil, or a wrong type alike" do
      pen = Emf::Emr::Binary::Records::CreatePen
      color = Emf::Binary::Types::ColorRef
      [color.new(red: 1, green: 2, blue: 3), { red: 1 }, { red: nil }, nil, 5, "x", [], { bogus: 1 }, color.new,
       { "red" => 1 }].each do |value|
        attrs = { i_type: 38, ih_pen: 1, color: value, width: { x: 3, y: 4 } }
        expect_same_bytes(pen, attrs)
      end
    end

    it "takes every nested struct as a plain Hash on the byte path, as emfsvg passes them" do
      records = Emf::Emr::Binary::Records
      cases = [
        [records::CreatePen, { i_type: 38, ih_pen: 4, pen_style: 0, width: { x: 2, y: 0 },
                               color: { red: 10, green: 20, blue: 30, reserved: 255 } }],
        [records::CreateBrushIndirect, { i_type: 39, ih_brush: 5, brush_style: 0, brush_hatch: 0,
                                         color: { red: 255, green: 0, blue: 128, reserved: 255 } }],
        [records::IntersectClipRect, { i_type: 30, rcl_clip: { left: -1, top: 0, right: 640, bottom: 480 } }],
        [records::Polygon, { i_type: 3, rcl_bounds: { left: 0, top: 0, right: 9, bottom: 9 }, cptl: 1, aptl: [{ x: 1, y: 2 }] }]
      ]
      cases.each do |klass, attrs|
        adapter = described_class.build(klass, **attrs)
        expect(adapter.instance_variable_get(:@wire)).to be_nil
        expect(adapter.to_binary_s).to eq(oracle.reference(klass, attrs).to_binary_s)
        expect(oracle.wire_view(adapter)).to eq(oracle.wire_view(oracle.reference(klass, attrs)))
      end
    end

    it "copies a struct value instead of sharing it with the caller" do
      pen = Emf::Emr::Binary::Records::CreatePen
      color = Emf::Binary::Types::ColorRef.new(red: 1, green: 2, blue: 3)
      adapter = described_class.build(pen, i_type: 38, color: color)
      bytes = adapter.to_binary_s
      color.red.assign(99)
      expect(adapter.to_binary_s).to eq(bytes)
      expect(adapter.wire.color.red.value).to eq(1)
    end

    it "does not retain a Hash the caller keeps mutating" do
      clip = Emf::Emr::Binary::Records::IntersectClipRect
      rect = { left: 1, top: 2, right: 3, bottom: 4 }
      adapter = described_class.build(clip, rcl_clip: rect)
      rect[:left] = 99
      expect(adapter.wire.rcl_clip.left.value).to eq(1)
    end
  end

  describe "records inside a metafile" do
    let(:header) { Emf.parse(Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")).header }

    def metafile_of(records, header)
      Emf::Model::Metafile.new(format: :emf, header: header, records: records)
    end

    it "serializes, parses, dumps and counts alike for factory-built and reference records" do
      attrs = oracle.planned_classes.map { |klass| [klass, oracle.full_attrs(klass)] }
      from_factory = metafile_of(attrs.map { |klass, a| oracle.built(klass, a) }, header)
      from_reference = metafile_of(attrs.map { |klass, a| oracle.reference(klass, a) }, header)
      factory_bytes = Emf.serialize(from_factory)
      expect(factory_bytes).to eq(Emf.serialize(from_reference))
      expect(Emf::Visitors::Stats.new.visit_all(from_factory).histogram).to eq(Emf::Visitors::Stats.new.visit_all(from_reference).histogram)
      expect(Emf::Visitors::Dump.new.visit_all(from_factory).to_s).to eq(Emf::Visitors::Dump.new.visit_all(from_reference).to_s)
      expect(Emf.serialize(Emf.parse(factory_bytes))).to eq(factory_bytes)
    end
  end

  describe "property test over random attribute values" do
    seed = Integer(ENV.fetch("WIRE_BUILD_SEED", "20261022"))
    iterations = Integer(ENV.fetch("WIRE_BUILD_ITERATIONS", "300"))

    filled.each do |klass|
      it "#{short.call(klass)} matches klass.new for #{iterations} random attribute sets (seed #{seed})" do
        random = Random.new(seed + klass.name.sum)
        byte_path = 0
        iterations.times do
          attrs = oracle.random_attrs(klass, random)
          expected = oracle.outcome { oracle.reference(klass, attrs).to_binary_s }
          actual = oracle.outcome { oracle.built(klass, attrs).to_binary_s }
          byte_path += 1 if oracle.outcome { oracle.built(klass, attrs).instance_variable_get(:@wire).nil? } == [:ok, true]
          expect(actual).to eq(expected), "seed=#{seed} class=#{klass} attrs=#{attrs.inspect}"
          next unless expected.first == :ok

          expect_same_snapshot(klass, attrs)
        end
        puts "#{short.call(klass)} byte path #{byte_path}/#{iterations}" if ENV["WIRE_BUILD_VERBOSE"]
        expect(byte_path).to be >= (oracle.planned_classes.include?(klass) ? 5 : 0)
      end
    end
  end
end
