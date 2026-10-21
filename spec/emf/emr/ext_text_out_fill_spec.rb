# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill::TextFill do
  codes = Emf::Emr::Binary::TypeCodes
  records = Emf::Emr::Binary::Records
  fast = Emf::Emr::Binary::FastFill
  bindata_writer = BinData::Base.instance_method(:to_binary_s)
  no_rect = 0x100
  tails = [0, 1, 17]
  nan_bits = [0x7fc12345].pack("V")

  types = { "ExtTextOutW" => codes::EXTTEXTOUTW, "ExtTextOutA" => codes::EXTTEXTOUTA }

  def text_bytes(type, options: 0, trailing: "hi\x00\x01".b, scales: [1.5, -2.25])
    rect = options.anybits?(0x100) ? [] : [1, 2, 3, 4]
    fields = [type, 0, -1, -2, 3, 4, 2, *scales.map { |s| [s].pack("e").unpack1("V") },
              -7, 9, 4, 76, options, *rect, 80]
    bytes = fields.pack("VVl<4VVVl<2V3#{'l<4' unless rect.empty?}V") + trailing
    bytes[4, 4] = [bytes.bytesize].pack("V")
    bytes
  end

  def same_wire?(wire, reference)
    wire.snapshot == reference.snapshot && wire.num_bytes == reference.num_bytes &&
      wire.trailing.value.encoding == reference.trailing.value.encoding
  end

  types.each do |name, type|
    describe name do
      let(:klass) { records.lookup(type) }
      let(:filler) { fast.for_text(type) }

      it "is enabled, and found by class" do
        expect(filler).to be_a(described_class)
        expect(filler.wire_class).to equal(klass)
        expect(fast.for_class(klass)).to equal(filler)
        expect(fast.for(type)).to be_nil
      end

      [0, no_rect, 0x4 | no_rect, 0x2].each do |options|
        tails.each do |tail|
          it "parses options #{options} with #{tail} trailing bytes like BinData" do
            bytes = text_bytes(type, options: options, trailing: ("x" * tail).b)
            wire, suffix = filler.call(bytes)
            reference = klass.read(bytes)

            expect(same_wire?(wire, reference)).to be(true)
            expect(suffix).to eq(Emf::Model::Emr::Records::WireAdapter.suffix_of(bytes, reference))
            expect(suffix).to be_empty
            expect(wire.to_binary_s).to eq(bytes)
            expect(bindata_writer.bind_call(wire)).to eq(bindata_writer.bind_call(reference))
            expect(wire.rcl.left.value).to eq(reference.rcl.left.value)
          end
        end
      end

      it "gives copies that do not share state" do
        first, = filler.call(text_bytes(type))
        second, = filler.call(text_bytes(type, options: no_rect))
        first.trailing.assign("zz".b)
        first.f_options.assign(0)
        expect(second.num_bytes).to eq(klass.read(text_bytes(type, options: no_rect)).num_bytes)
        expect(second.trailing.value).to eq("hi\x00\x01".b)
      end

      it "leaves records shorter than their layout to BinData" do
        rect = text_bytes(type, trailing: "".b)
        expect(filler.call(rect.byteslice(0, 70))).to be_nil
        expect(filler.call(rect.byteslice(0, 40))).to be_nil
        expect { klass.read(rect.byteslice(0, 70)) }.to raise_error(IOError)
        short = text_bytes(type, options: no_rect, trailing: "".b)
        expect(filler.call(short)).not_to be_nil
        expect(filler.call(short.byteslice(0, 59))).to be_nil
      end

      it "keeps NaN scale bits through parse and serialize" do
        bytes = text_bytes(type)
        bytes[28, 4] = nan_bits
        wire, = filler.call(bytes)
        expect(wire.to_binary_s).to eq(bytes)
      end

      it "packs like BinData's writer, and declines a NaN scale" do
        wire, = filler.call(text_bytes(type, scales: [0.1, 1e30]))
        expect(filler.pack(wire)).to eq(bindata_writer.bind_call(wire))
        wire.ex_scale.assign(Float::NAN)
        expect(filler.pack(wire)).to be_nil
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(wire))
      end

      it "packs a record built from attributes with either rect state" do
        [0, no_rect].each do |options|
          wire = klass.new(i_type: type, f_options: options, rcl: { left: 1, top: 2, right: 3, bottom: 4 },
                           trailing: "ab".b)
          expect(wire.to_binary_s).to eq(bindata_writer.bind_call(wire))
        end
      end

      [0, no_rect].each do |options|
        describe "keyword construction with options #{options}" do
          let(:attrs) do
            { i_type: type, rcl_bounds: Emf::Binary::Types::RectL.new(left: 1, top: 2, right: 3, bottom: 4),
              i_graphics_mode: 2, ex_scale: 1.0, ey_scale: 1.0,
              ptl_reference: Emf::Binary::Types::PointL.new(x: 5, y: -6), n_chars: 2, off_string: 76,
              f_options: options, rcl: Emf::Binary::Types::RectL.new(left: 0, top: 0, right: 0, bottom: 0),
              off_dx: 80, trailing: "a\x00b\x00".b }
          end

          it "equals the BinData-built object" do
            wire = klass.new(**attrs)
            reference = klass.new(attrs.dup)
            expect(same_wire?(wire, reference)).to be(true)
            expect(wire.to_binary_s).to eq(bindata_writer.bind_call(reference))
          end

          it "equals BinData without the rect, and with hash nesting" do
            partial = attrs.except(:rcl).merge(ptl_reference: { x: 1, y: 2 })
            expect(same_wire?(klass.new(**partial), klass.new(partial.dup))).to be(true)
          end
        end
      end

      it "builds an unknown key like BinData does" do
        expect(filler.build(bogus: 1)).to be_nil
        expect(klass.new(bogus: 1).snapshot).to eq(klass.new({ bogus: 1 }).snapshot)
      end
    end
  end

  it "parses the text records of a fixture identically to BinData" do
    bytes = File.binread(File.join(__dir__, "../../fixtures/emf-ea/EA-test-file-011.emf"))
    pos = 0
    seen = 0
    while pos + 8 <= bytes.bytesize
      type, size = bytes.unpack("VV", offset: pos)
      break if size < 8 || pos + size > bytes.bytesize

      if types.value?(type)
        record = bytes.byteslice(pos, size)
        wire, suffix = fast.for_text(type).call(record)
        reference = records.lookup(type).read(record)
        expect(same_wire?(wire, reference)).to be(true)
        expect(wire.to_binary_s).to eq(record)
        expect(suffix).to be_empty
        seen += 1
      end
      pos += size
    end
    expect(seen).to be > 100
  end
end
