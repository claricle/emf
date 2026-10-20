# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::ObjectTable do
  include Emf::SpecSupport::EmfPlusRecords

  let(:plus) { Emf::EmfPlus }
  let(:types) { plus::Objects }

  def decode_all(bytes)
    plus::Records.decode_all(plus::Parser.call(bytes))
  end

  def object(type, id, data = "obj!".b, total: nil)
    flags = (type << 8) | id
    flags |= 0x8000 if total
    body = total ? [total].pack("V") + data : data
    record(0x4008, body, flags: flags)
  end

  def stream(*parts) = decode_all(parts.join.b)

  def draw_rects(pen) = record(0x400B, [1].pack("V") + [0, 0, 1, 1].pack("s<4"), flags: 0x4000 | pen)

  def fill_rects(brush, solid: false)
    record(0x400A, [brush, 1].pack("VV") + [0, 0, 1, 1].pack("s<4"), flags: 0x4000 | (solid ? 0x8000 : 0))
  end

  def fill_path(path, brush, solid: false) = record(0x4014, [brush].pack("V"), flags: path | (solid ? 0x8000 : 0))
  def draw_path(path, pen) = record(0x4015, [pen].pack("V"), flags: path)
  def draw_string(font, brush, format) = record(0x401C, [brush, format, 0].pack("VVV") + ([0.0] * 4).pack("e4"), flags: font)
  def draw_image(image, attrs) = record(0x401A, [attrs, 2].pack("VV") + ([0.0] * 8).pack("e8"), flags: image)
  def fill_region(region, brush) = record(0x4013, [brush].pack("V"), flags: region)

  describe "slots and time-indexed lookup" do
    let(:records) do
      stream(object(types::PEN, 3, "old!"), draw_rects(3), object(types::PEN, 3, "new!"), draw_rects(3))
    end
    let(:table) { described_class.new(records) }

    it "resolves a draw before redefinition to the old object and after it to the new one" do
      expect(table.resolve(records[1], at: 1).first.object.data).to eq("old!")
      expect(table.resolve(records[3], at: 3).first.object.data).to eq("new!")
    end

    it "does not show an object at its own position" do
      expect(table.lookup(3, at: 0)).to be_nil
      expect(table.lookup(3, at: 2).data).to eq("old!")
      expect(table.lookup(3, at: 3).data).to eq("new!")
    end

    it "snapshots all 64 slots with #at" do
      slots = table.at(2)

      expect(slots.size).to eq(64)
      expect(slots.each_index.reject { |id| slots[id].nil? }).to eq([3])
    end

    it "accepts ID 63 and rejects 64 on lookup" do
      table = described_class.new(stream(object(types::PEN, 63)))

      expect(table.lookup(63, at: 1)).not_to be_nil
      expect { table.lookup(64, at: 1) }.to raise_error(Emf::EmfPlus::ObjectIdError, /64/)
      expect(Emf::EmfPlus::ObjectIdError.ancestors).to include(Emf::Error)
    end
  end

  describe "out-of-range IDs" do
    let(:records) { stream(object(types::PEN, 64), object(types::PEN, 255), object(types::PEN, 2)) }
    let(:table) { described_class.new(records) }

    it "records a diagnostic per object and keeps the records" do
      expect(table.errors.map(&:kind)).to eq(%i[object_id_out_of_range object_id_out_of_range])
      expect(table.errors.map(&:id)).to eq([64, 255])
      expect(table.errors.first.records.first.to_binary).to eq(records[0].to_binary)
    end

    it "does not place them and raises on lookup" do
      expect(table.at(3).compact.size).to eq(1)
      expect { table.lookup(64, at: 3) }.to raise_error(Emf::EmfPlus::ObjectIdError)
    end

    it "turns an out-of-range draw reference into a diagnostic" do
      draw = decode_all(draw_path(1, 200)).first

      expect(table.resolve(draw, at: 3).last.diagnostic.kind).to eq(:object_id_out_of_range)
    end
  end

  describe "continuation chains" do
    it "keeps chunk boundaries of a synthetic chain and places it at its last chunk" do
      records = stream(object(types::IMAGE, 5, "abcd", total: 8), object(types::IMAGE, 5, "efgh", total: 8), draw_rects(0))
      table = described_class.new(records)

      logical = table.lookup(5, at: 2)
      expect(logical.data).to eq("abcdefgh")
      expect(logical.chunk_sizes).to eq([4, 4])
      expect(table.lookup(5, at: 1)).to be_nil
      expect(table.errors).to be_empty
    end

    it "reports an incomplete chain with its bytes and does not place it" do
      records = stream(object(types::IMAGE, 5, "abcd", total: 12), object(types::IMAGE, 5, "efgh", total: 12), draw_rects(0))
      table = described_class.new(records)

      expect(table.errors.map(&:kind)).to eq([:incomplete_chain])
      expect(table.errors.first.records.map(&:to_binary)).to eq(records[0, 2].map(&:to_binary))
      expect(table.lookup(5, at: 3)).to be_nil
    end

    it "gives back the record that broke the chain" do
      records = stream(object(types::IMAGE, 5, "abcd", total: 12), object(types::PEN, 7, "pen!"))
      table = described_class.new(records)

      expect(table.errors.first.records.size).to eq(1)
      expect(table.lookup(7, at: 2).data).to eq("pen!")
    end

    %w[test-109 test-155].each do |name|
      context name do
        let(:metafile) { Emf.parse(File.binread(File.expand_path("../../fixtures/emf/#{name}.emf", __dir__))) }
        let(:records) { plus::Records.decode_all(plus::Parser.from_metafile(metafile)) }
        let(:table) { described_class.new(records) }
        let(:chunks) { records.select { |r| r.is_a?(plus::Records::Object) && r.continued? } }

        it "reassembles the image object and keeps chunk boundaries" do
          logical = table.lookup(chunks.first.emf_object_id, at: records.index(chunks.last) + 1)

          expect(chunks.size).to be > 1
          expect(logical.object_type).to eq(types::IMAGE)
          expect(logical.chunk_sizes).to eq(chunks.map { |c| c.object_data.bytesize })
          expect(logical.data).to eq(chunks.map(&:object_data).join.b)
          expect(logical.split.map(&:to_binary)).to eq(chunks.map(&:to_binary))
          expect(table.errors).to be_empty
        end

        it "resolves the DrawImagePoints reference to that object" do
          draws = records.each_index.select { |i| records[i].is_a?(plus::Records::DrawImagePoints) }
          resolved = draws.map { |i| table.resolve(records[i], at: i).first }

          expect(resolved.map(&:role).uniq).to eq([:image])
          expect(resolved.map(&:diagnostic)).to all(be_nil)
          expect(resolved.map { |r| r.object.object_type }.uniq).to eq([types::IMAGE])
        end
      end
    end
  end

  describe "resolving references" do
    let(:records) do
      stream(
        object(types::PEN, 1), object(types::BRUSH, 2), object(types::FONT, 3), object(types::STRING_FORMAT, 4),
        object(types::IMAGE, 5), object(types::IMAGE_ATTRIBUTES, 6), object(types::PATH, 7), object(types::REGION, 8),
        draw_rects(1), fill_rects(2), fill_rects(0x80FF0000, solid: true), draw_string(3, 2, 4), draw_image(5, 6),
        draw_path(7, 1), fill_path(7, 2), fill_region(8, 2)
      )
    end
    let(:table) { described_class.new(records) }

    def resolve(index) = table.resolve(records[index], at: index)

    it "resolves a pen" do
      result = resolve(8).first

      expect(result).to have_attributes(role: :pen, raw_id: 1, diagnostic: nil)
      expect(result.object).to be(table.lookup(1, at: 8))
    end

    it "resolves a brush object" do
      expect(resolve(9).first).to have_attributes(role: :brush, raw_id: 2, solid_color: nil, diagnostic: nil)
      expect(resolve(9).first.object.object_type).to eq(types::BRUSH)
    end

    it "keeps an S-flag BrushId as a raw colour and does not look it up" do
      expect(resolve(10).first).to have_attributes(role: :brush, raw_id: 0x80FF0000, object: nil, diagnostic: nil, solid_color: true)
    end

    it "resolves font, brush and string format of DrawString" do
      expect(resolve(11).map { |r| [r.role, r.raw_id, r.object.object_type] })
        .to eq([[:font, 3, types::FONT], [:brush, 2, types::BRUSH], [:string_format, 4, types::STRING_FORMAT]])
    end

    it "resolves image and image attributes of DrawImage" do
      expect(resolve(12).map { |r| [r.role, r.object.object_type] })
        .to eq([[:image, types::IMAGE], [:image_attributes, types::IMAGE_ATTRIBUTES]])
    end

    it "resolves path, pen and region references of path and region records" do
      expect(resolve(13).map { |r| [r.role, r.object.object_type] }).to eq([[:path, types::PATH], [:pen, types::PEN]])
      expect(resolve(14).map { |r| [r.role, r.object.object_type] }).to eq([[:path, types::PATH], [:brush, types::BRUSH]])
      expect(resolve(15).map { |r| [r.role, r.object.object_type] }).to eq([[:region, types::REGION], [:brush, types::BRUSH]])
    end

    it "gives records without references no resolutions" do
      expect(table.resolve(records[0], at: 0)).to eq([])
    end

    it "reports an empty slot as a diagnostic, not an exception" do
      draw = decode_all(draw_rects(9)).first
      result = table.resolve(draw, at: 16).first

      expect(result.object).to be_nil
      expect(result.diagnostic).to have_attributes(kind: :empty_slot, id: 9, stream_index: 16, records: [draw])
    end

    it "reports an object defined only after the draw as an empty slot" do
      expect(table.resolve(records[8], at: 0).first.diagnostic.kind).to eq(:empty_slot)
    end

    it "reports a wrong object type as a diagnostic and keeps the raw ID" do
      draw = decode_all(draw_rects(2)).first
      result = table.resolve(draw, at: 16).first

      expect(result).to have_attributes(raw_id: 2, object: nil)
      expect(result.diagnostic.kind).to eq(:wrong_type)
    end
  end
end
