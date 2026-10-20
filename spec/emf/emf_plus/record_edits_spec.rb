# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"
require_relative "../../support/emf_plus_edit_examples"

RSpec.describe "EMF+ record edits" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:records) { Emf::EmfPlus::Records }
  let(:examples) { Emf::SpecSupport::EmfPlusEditExamples }

  def decode(bytes) = records.decode(Emf::EmfPlus::Parser.call(bytes).first)

  def reparse(record) = decode(record.to_binary)

  def deep_merge(base, edit)
    return edit unless base.is_a?(Hash) && edit.is_a?(Hash)

    base.merge(edit) { |_key, old, new| deep_merge(old, new) }
  end

  def build(example, klass) = decode(record(klass::TYPE, example.body, flags: example.flags))

  it "has an edit example for every registered record type and none for unregistered ones" do
    expect(examples.all.keys).to match_array(records.registry.values)
  end

  Emf::EmfPlus::Records.registry.each_value do |klass|
    describe klass.name.split("::").last do
      let(:example) { examples.for_class(klass) }
      let(:original) { build(example, klass) }
      let(:edited) { original.with(**example.edit) }
      let(:edited_fields) { example.edit.except(:flags, *original.flag_fields.keys) }

      it "starts from a record that re-encodes unchanged" do
        expect(original.to_binary).to eq(record(klass::TYPE, example.body, flags: example.flags))
      end

      it "returns an edited record of the same class and leaves the receiver untouched" do
        before = original.to_binary

        expect(edited).to be_a(klass)
        expect(original.to_binary).to eq(before)
      end

      it "re-parses with the edited fields and every other body field unchanged" do
        expected = deep_merge(original.body.snapshot, edited_fields)

        expect(reparse(edited).body.snapshot).to eq(expected)
      end

      it "re-parses with the expected flags" do
        expect(reparse(edited).flags).to eq(example.flags_after)
      end

      it "keeps Size aligned and DataSize equal to the body length" do
        frame = Emf::EmfPlus::Parser.call(edited.to_binary).first

        expect(frame.size % 4).to eq(0)
        expect(frame.data_size).to eq(edited.body.num_bytes)
      end
    end
  end

  describe "flag-backed attributes" do
    Emf::EmfPlus::Records.registry.each_value do |klass|
      instance = Emf::SpecSupport::EmfPlusEditExamples.for_class(klass)
      probe = klass.new(Emf::EmfPlus::Frame.new(type: klass::TYPE, flags: instance.flags, size: 12 + instance.body.bytesize,
                                                data_size: instance.body.bytesize, data: instance.body))
      probe.flag_fields.each do |name, mask|
        it "#{klass.name.split('::').last} #{name} rewrites only its own bits" do
          shift = (mask & -mask).bit_length - 1
          value = ((instance.flags & mask) >> shift) ^ 1
          edited = probe.with(name => value)

          expect(edited.flags).to eq((instance.flags & ~mask) | (value << shift))
        end
      end
    end

    it "accepts booleans for bit flags and rejects values that do not fit the field" do
      mode = build(examples.for_class(records::SetAntiAliasMode), records::SetAntiAliasMode)

      expect(mode.with(anti_alias: false).flags).to eq(0x0004)
      expect { mode.with(smoothing_mode: 0x80) }.to raise_error(ArgumentError, /smoothing_mode must fit 7 bit/)
      expect { mode.with(anti_alias: nil) }.to raise_error(ArgumentError, /anti_alias must fit/)
    end
  end

  describe "layout-selecting flags" do
    let(:rects) { build(examples.for_class(records::DrawRects), records::DrawRects) }

    it "re-reads the body in the layout the new flags select" do
      compact = rects.with(compressed: true, rect_data: { compressed_rects: [{ x: 1, y: 2, width: 3, height: 4 }] })
      reparsed = reparse(compact)

      expect(reparsed).to be_compressed
      expect(reparsed.rects.map(&:snapshot)).to eq([{ x: 1, y: 2, width: 3, height: 4 }])
      expect(compact.size).to eq(12 + 4 + 8)
    end
  end

  describe "variable-length edits" do
    let(:rects) { build(examples.for_class(records::DrawRects), records::DrawRects) }

    def float_rects(count) = Array.new(count) { |i| { x: i * 1.0, y: 0.0, width: 1.0, height: 1.0 } }

    [0, 1, 3, 5].each do |count|
      it "sets Size and DataSize for #{count} rect(s)" do
        edited = rects.with(item_count: count, rect_data: { float_rects: float_rects(count) })
        frame = Emf::EmfPlus::Parser.call(edited.to_binary).first

        expect([frame.size, frame.data_size]).to eq([12 + 4 + (16 * count), 4 + (16 * count)])
        expect(reparse(edited).rects.map(&:snapshot)).to eq(float_rects(count))
      end
    end

    it "re-pads Size when the new DataSize is not 4-byte aligned" do
      comment = decode(record(0x4003, "abcd"))
      frame = Emf::EmfPlus::Parser.call(comment.with(private_data: "abcde").to_binary).first

      expect([frame.size, frame.data_size]).to eq([12 + 8, 5])
    end

    it "grows and shrinks point lists" do
      lines = build(examples.for_class(records::DrawLines), records::DrawLines)
      points = Array.new(6) { |i| { x: i * 1.0, y: 1.0 } }

      expect(reparse(lines.with(item_count: 6, point_data: { float_points: points })).points.map(&:snapshot)).to eq(points)
      fewer = lines.with(item_count: 1, point_data: { float_points: points.first(1) })

      expect(reparse(fewer).points.map(&:snapshot)).to eq(points.first(1))
    end
  end

  describe "trailing bytes" do
    let(:body) { [2].pack("V") + ([1.0, 2.0, 3.0, 4.0] * 2).pack("e*") }

    it "drops alignment padding and re-pads for the new body" do
      padded = decode(record(0x4003, "abcde\0\0\0", data_size: 5))
      edited = padded.with(private_data: "abcdefg")

      expect(padded.trailing).to eq("\0\0\0".b)
      expect(edited.to_binary.bytesize).to eq(12 + 8)
      expect(edited.trailing).to eq("\0".b)
    end

    it "keeps unknown trailing data after the body and counts it in DataSize" do
      raw = record(0x400B, body + "\x01\x02\x03\x04".b, flags: 0, data_size: 4 + 32 + 4)
      original = decode(raw)
      edited = original.with(emf_object_id: 3)

      expect(original.trailing).to eq("\x01\x02\x03\x04".b)
      expect(edited.trailing).to eq("\x01\x02\x03\x04".b)
      expect(edited.to_binary).to eq(record(0x400B, body + "\x01\x02\x03\x04".b, flags: 3, data_size: 4 + 32 + 4))
    end

    it "keeps four or more zero bytes, which are data and not alignment padding" do
      raw = record(0x400B, body + ("\0" * 4), data_size: 4 + 32 + 4)

      expect(decode(raw).with(emf_object_id: 3).to_binary).to eq(record(0x400B, body + ("\0" * 4), flags: 3, data_size: 4 + 32 + 4))
    end

    it "round-trips an empty edit byte-for-byte" do
      raw = record(0x4003, "abcde\0\0\0", data_size: 5)

      expect(decode(raw).with.to_binary).to eq(raw)
    end
  end

  describe "invalid edits" do
    let(:clear) { build(examples.for_class(records::Clear), records::Clear) }

    it "rejects an unknown field and names the record" do
      expect { clear.with(colour: 1) }.to raise_error(ArgumentError, /unknown field\(s\) colour for Emf::EmfPlus::Records::Clear/)
    end
  end

  describe "a real corpus stream" do
    let(:metafile) { Emf.parse(File.binread(File.expand_path("../../fixtures/emf-ea/EA-test-file-020.emf", __dir__))) }
    let(:original) { records.decode_all(Emf::EmfPlus::Parser.call(metafile.emf_plus)) }
    let(:index) { original.index { |r| r.is_a?(records::FillRects) } }
    let(:grown) do
      layout = original[index].compressed? ? :compressed_rects : :float_rects
      extra = original[index].rects.map(&:snapshot) + [{ x: 0, y: 0, width: 2, height: 2 }]
      original[index].with(item_count: extra.size, rect_data: { layout => extra })
    end
    let(:edited_stream) do
      original.dup.tap { |all| all[index] = grown }
    end

    it "changes only the edited record when the stream is re-serialized and re-parsed" do
      reparsed = records.decode_all(Emf::EmfPlus::Parser.call(Emf::EmfPlus::Serializer.call(edited_stream)))
      untouched = (0...original.size).reject { |i| i == index }

      expect(reparsed.size).to eq(original.size)
      expect(untouched.map { |i| reparsed[i].to_binary }).to eq(untouched.map { |i| original[i].to_binary })
      expect(reparsed[index].rects.size).to eq(original[index].rects.size + 1)
      expect(reparsed[index].brush_id).to eq(original[index].brush_id)
    end
  end
end
