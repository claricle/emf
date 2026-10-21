# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

# Semantics mirror emf-rs/crates/emf-core/src/wmf/{brush,escape}.rs.
RSpec.describe "WMF pattern-brush target and Escape subtype views" do
  include NativeWmfSupport

  def records_for(*wire)
    Emf::Wmf::Parser.call(native_wmf_bytes(wire)).records
  end

  def escape_record(subtype, data, padding: nil)
    Emf::Model::Wmf::Records::Escape.new(escape_function: subtype, data: data.b, padding: padding)
  end

  describe "DibCreatePatternBrush" do
    let(:target) do
      [40, 1, 1, 1, 8].pack("Vl<2v2") + [0, 0, 123, 456, 2, 0].pack("V2l<2V2") +
        [1, 2, 3, 4, 5, 6, 7, 8, 0, 0xEE, 0xDD, 0xCC].pack("C*")
    end

    it "exposes the target as a packed DIB using the stored color usage" do
      brush = records_for(native_wmf_record(0x0142, [0, 0].pack("v2") + target)).first

      expect(brush.effective_color_usage).to eq(0)
      expect(brush.target_dib.colors.to_h).to eq(kind: :rgb_quads, rows: [[1, 2, 3, 4], [5, 6, 7, 8]])
      expect(brush.target).to eq(target)
    end

    it "uses palette indices for usage 1" do
      palette = target.dup
      palette = palette.byteslice(0, 40) + [7, 0, 8, 0, 0, 0xEE, 0xDD, 0xCC].pack("C*")
      brush = records_for(native_wmf_record(0x0142, [0, 1].pack("v2") + palette)).first

      expect(brush.target_dib.colors.to_h).to eq(kind: :palette_indices, rows: [7, 8])
    end

    it "ignores the stored usage for BS_PATTERN and always reads RGB colors" do
      brush = records_for(native_wmf_record(0x0142, [3, 7].pack("v2") + target)).first

      expect([brush.effective_color_usage, brush.target_dib.colors.kind]).to eq([0, :rgb_quads])
    end

    it "returns nil for an unsupported target without touching the raw bytes" do
      brush = records_for(native_wmf_record(0x0142, [0, 0].pack("v2") + ("\0" * 8))).first

      expect([brush.target_dib, brush.target]).to eq([nil, "\0".b * 8])
    end
  end

  describe "Escape#typed_payload" do
    it "recognizes empty subtypes and reports unknown ones as nil" do
      expect(escape_record(0x0001, "").typed_payload.to_h).to eq(kind: :new_frame, fields: {})
      expect(escape_record(0x0C01, "").typed_payload.kind).to eq(:query_dib_support)
      expect(escape_record(0x7777, "").typed_payload).to be_nil
    end

    it "decodes fixed-size payloads, keeping private and reserved values" do
      rect = [-1, 2, 3, -4].pack("l<4") + [5, 6].pack("v2")

      expect(escape_record(0x1001, [9, 0xFFFF].pack("v2")).typed_payload.to_h)
        .to eq(kind: :clip_to_path, fields: { clip_function: 9, reserved1: 0xFFFF })
      expect(escape_record(0x0019, rect).typed_payload.fields)
        .to eq(position_x: -1, position_y: 2, size_width: 3, size_height: -4, style: 5, pattern: 6)
      expect(escape_record(0x0015, [-2].pack("l<")).typed_payload.fields).to eq(cap: -2)
      expect(escape_record(0x0011, [3].pack("v")).typed_payload.fields).to eq(copy_count: 3)
    end

    it "rejects unexpected sizes and any alignment byte" do
      expect(escape_record(0x0015, "\0\0".b).typed_payload).to be_nil
      expect(escape_record(0x0011, "\x03\0\0".b, padding: 0).typed_payload).to be_nil
    end

    it "is nil unless the record function is Escape" do
      record = escape_record(0x0001, "")
      record.instance_variable_set(:@type_id, 0x0127)

      expect(record.typed_payload).to be_nil
    end
  end

  describe "Escape#typed_counted_payload" do
    it "returns the exact counted bytes for each counted subtype" do
      { 0x0013 => :passthrough, 0x0025 => :postscript_data, 0x1013 => :postscript_passthrough, 0x1017 => :check_jpeg_format,
        0x1018 => :check_png_format, 0x0004 => :set_color_table }.each do |subtype, kind|
        expect(escape_record(subtype, "ab").typed_counted_payload.to_h).to eq(kind: kind, data: "ab".b)
      end
    end

    it "requires alignment to match the count and bounds STARTDOC below 260 bytes" do
      expect(escape_record(0x0013, "abc", padding: 0).typed_counted_payload.data).to eq("abc".b)
      expect(escape_record(0x0013, "abc").typed_counted_payload).to be_nil
      expect(escape_record(0x0013, "ab", padding: 0).typed_counted_payload).to be_nil
      expect(escape_record(0x000A, "x" * 259, padding: 0).typed_counted_payload.kind).to eq(:start_doc)
      expect(escape_record(0x000A, "x" * 260).typed_counted_payload).to be_nil
      expect(escape_record(0x7777, "ab").typed_counted_payload).to be_nil
    end
  end

  describe "Escape#typed_special_passthrough2_payload" do
    it "borrows the data bounded by the inner size" do
      payload = [0xAABBCCDD, 3].pack("Vv") + "xyz".b
      view = escape_record(0x11D8, payload, padding: 0).typed_special_passthrough2_payload

      expect(view.to_h).to eq(reserved: 0xAABBCCDD, data: "xyz".b)
    end

    it "rejects a size that does not consume the payload exactly" do
      short = [1, 4].pack("Vv") + "xyz".b
      long = [1, 2].pack("Vv") + "xyz".b

      expect([short, long].map { |data| escape_record(0x11D8, data, padding: 0).typed_special_passthrough2_payload }).to eq([nil, nil])
      expect(escape_record(0x11D8, "\0\0\0".b, padding: 0).typed_special_passthrough2_payload).to be_nil
      expect(escape_record(0x0013, [1, 0].pack("Vv")).typed_special_passthrough2_payload).to be_nil
    end
  end

  it "works on records read from a document and does not change serialization" do
    wire = native_wmf_escape(0x0013, "abc".b)
    bytes = native_wmf_bytes([wire])
    metafile = Emf::Wmf::Parser.call(bytes)

    expect(metafile.records.first.typed_counted_payload.data).to eq("abc".b)
    expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
  end
end
