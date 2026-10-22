# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_payload_builder"

RSpec.describe "EMF+ payload rules" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:payload) { Emf::SpecSupport::EmfPlusPayloadBuilder }

  def found(records, id, profile: :strict) = build.diagnostics(build.stream(*records), id, profile: profile)

  def messages(records, id) = found(Array(records), id).map(&:message)

  describe "emfplus.draw.driver_string" do
    it "accepts the formula with and without a matrix, including padding for an odd glyph count" do
      [payload.driver_string(count: 3), payload.driver_string(count: 4, matrix: true), payload.driver_string(count: 0)].each do |record|
        expect(found([record], "emfplus.draw.driver_string")).to be_empty
      end
    end

    it "flags a DataSize that disagrees with GlyphCount" do
      diagnostic = found([payload.driver_string(count: 3, size: 64, data_size: 52)], "emfplus.draw.driver_string").first
      expect(diagnostic.message).to include("DrawDriverString", "DataSize is 52", "GlyphCount 3")
      expect([diagnostic.offset, diagnostic.record_type]).to eq([88, 0x4036])
    end

    it "names the formula, not body_bounds, when a GlyphCount runs past the record (an undecodable body)" do
      record = payload.driver_string(count: 3, glyph_count: 50)
      expect(messages(record, "emfplus.draw.driver_string").first).to include("GlyphCount 50")
      expect(messages(record, "emfplus.record.body_bounds")).to be_empty
    end

    it "uses the 40-byte fixed part when the matrix is present" do
      bad = payload.driver_string(count: 2, matrix: true, size: 12 + 36, data_size: 36)
      expect(messages(bad, "emfplus.draw.driver_string").first).to include("DataSize is 36", "GlyphCount * 10 + 40")
    end
  end

  describe "emfplus.draw.driver_string_matrix and _options" do
    it "requires MatrixPresent 0 or 1" do
      expect(messages(payload.driver_string(matrix_present: 2), "emfplus.draw.driver_string_matrix").first).to include("is 2")
      [0, 1].each do |value|
        record = payload.driver_string(matrix: value == 1)
        expect(found([record], "emfplus.draw.driver_string_matrix")).to be_empty
      end
    end

    it "accepts any combination of the four DriverStringOptions flags and flags other bits" do
      (0..15).each { |options| expect(found([payload.driver_string(options: options)], "emfplus.draw.driver_string_options")).to be_empty }
      expect(messages(payload.driver_string(options: 0x10), "emfplus.draw.driver_string_options").first).to include("0x00000010")
    end
  end

  describe "emfplus.draw.string" do
    it "accepts Length matching DataSize, with 0 to 3 padding bytes" do
      [payload.draw_string(text: "abc"), payload.draw_string(text: "ab"), payload.draw_string(text: "abcd")].each do |record|
        expect(found([record], "emfplus.draw.string")).to be_empty
      end
    end

    it "flags Length that disagrees with DataSize in either direction" do
      long = payload.draw_string(text: "abc", length: 1, size: 12 + 36, data_size: 36)
      expect(messages(long, "emfplus.draw.string").first).to include("DrawString", "Length 1", "MUST be 30 plus up to 3")
      short = payload.draw_string(text: "abc", length: 9)
      expect(messages(short, "emfplus.draw.string").first).to include("Length 9")
      expect(messages(short, "emfplus.record.body_bounds")).to be_empty
    end

    it "does not count the string-format or font references (those are object rules)" do
      expect(found([payload.draw_string], "emfplus.draw.string")).to be_empty
    end
  end

  describe "emfplus.draw.image" do
    it "accepts the documented Size and DataSize for DrawImage and each DrawImagePoints form" do
      records = [payload.draw_image, payload.draw_image(compressed: true), payload.draw_image_points,
                 payload.draw_image_points(flags: 0x4000), payload.draw_image_points(flags: 0x0800)]
      records.each { |record| expect(found([record], "emfplus.draw.image")).to be_empty }
    end

    it "flags a DrawImage whose size does not match the C flag" do
      bad = payload.draw_image(compressed: true, size: 0x34, data_size: 0x28)
      expect(messages(bad, "emfplus.draw.image").first).to include("DrawImage", "DataSize is 40, MUST be 32", "Size is 52, MUST be 44")
    end

    it "flags a DrawImagePoints whose size does not match the P and C flags" do
      bad = payload.draw_image_points(size: 0x34, data_size: 0x28)
      expect(messages(bad, "emfplus.draw.image").first).to include("DrawImagePoints", "DataSize is 40, MUST be 52")
    end
  end

  describe "emfplus.object.serializable, _guid and _buffer" do
    it "accepts a well-formed Blur effect" do
      record = payload.serializable
      %w[serializable serializable_guid serializable_buffer].each { |id| expect(found([record], "emfplus.object.#{id}")).to be_empty }
    end

    it "flags Size and DataSize that disagree with BufferSize, and a BufferSize that is not 32-bit aligned" do
      bad = payload.serializable(buffer_size: 4, size: 12 + 20 + 8, data_size: 20 + 8)
      expect(messages(bad, "emfplus.object.serializable").first).to include("DataSize is 28, MUST be 24", "Size = BufferSize + 0x20")
      odd = payload.serializable(buffer: "\0" * 6)
      expect(messages(odd, "emfplus.object.serializable").first).to include("BufferSize 6 is not a multiple of 4")
    end

    it "flags a GUID that is not an image effect" do
      bad = payload.serializable(guid: "00000000-0000-0000-0000-000000000001")
      expect(messages(bad, "emfplus.object.serializable_guid").first).to include("00000000-0000-0000-0000-000000000001")
    end

    it "flags a buffer that does not fit the effect, or runs past it" do
      short = payload.serializable(buffer: "\0" * 4)
      expect(messages(short, "emfplus.object.serializable_buffer").first).to include("does not hold its effect parameter block")
      long = payload.serializable(buffer: "\0" * 16)
      expect(messages(long, "emfplus.object.serializable_buffer").first).to include("8 bytes beyond")
    end
  end

  describe "emfplus.terminal.clip" do
    it "accepts the 8-byte form exactly and the 4-byte form at or above its minimum" do
      expect(found([payload.ts_clip(count: 2)], "emfplus.terminal.clip")).to be_empty
      expect(found([payload.ts_clip(count: 2, compressed: true)], "emfplus.terminal.clip")).to be_empty
      varied = payload.ts_clip(count: 2, compressed: true, data: "\0" * 12)
      expect(found([varied], "emfplus.terminal.clip")).to be_empty
    end

    it "flags NumRects whose rectangles do not fit DataSize" do
      expect(messages(payload.ts_clip(count: 2, data: "\0" * 8), "emfplus.terminal.clip").first)
        .to include("SetTSClip", "DataSize is 8, MUST be 16", "NumRects 2")
      expect(messages(payload.ts_clip(count: 3, compressed: true, data: "\0" * 8), "emfplus.terminal.clip").first)
        .to include("below 12")
    end
  end

  describe "emfplus.terminal.graphics_*" do
    let(:ts_ids) { %w[emfplus.terminal.graphics emfplus.terminal.graphics_palette emfplus.terminal.graphics_enums] }

    it "accepts a state record with and without a palette" do
      [payload.ts_graphics, payload.ts_graphics(palette: payload.palette(2), contrast: 12)].each do |record|
        ts_ids.each { |id| expect(found([record], id)).to be_empty }
      end
    end

    it "flags a T-clear record whose DataSize is not 0x24" do
      bad = payload.ts_graphics(size: 12 + 40, data_size: 40)
      expect(messages(bad, "emfplus.terminal.graphics").first).to include("SetTSGraphics", "DataSize is 40, MUST be 36")
    end

    it "flags palette bytes that are not exactly one EmfPlusPalette" do
      short = payload.palette(3)[0...-4]
      expect(messages(payload.ts_graphics(palette: short),
                      "emfplus.terminal.graphics_palette").first).to include("not exactly one EmfPlusPalette")
      expect(messages(payload.ts_graphics(palette: payload.palette(2) + ("\0" * 4)), "emfplus.terminal.graphics_palette")).not_to be_empty
    end

    it "flags enumeration fields outside their domain" do
      { contrast: 13, filter: 5, pixel_offset: 5, anti_alias: 6, compositing_mode: 2, compositing_quality: 0,
        text_hint: 6 }.each do |field, value|
        expect(messages(payload.ts_graphics(field => value), "emfplus.terminal.graphics_enums").size).to eq(1), field.to_s
      end
      expect(messages(payload.ts_graphics(contrast: 13),
                      "emfplus.terminal.graphics_enums").first).to include("TextContrast value 13", "0..12")
    end
  end

  describe "emfplus.object.type and emfplus.object.payload" do
    def object(type, id, data) = build.object(type, id, data)

    it "accepts well-formed font, image and string-format payloads" do
      records = [object(6, 1, payload.font), object(5, 2, payload.bitmap_image), object(5, 3, payload.metafile_image)]
      %w[type payload].each { |part| expect(found(records, "emfplus.object.#{part}")).to be_empty }
    end

    it "flags ObjectType 0 and above 9" do
      expect(messages(object(0, 1, "\0" * 4), "emfplus.object.type").first).to include("ObjectType is 0")
      expect(messages(object(10, 1, "\0" * 4), "emfplus.object.type").first).to include("ObjectType is 10")
    end

    it "flags a font whose FamilyName runs past the object, at the defining record" do
      diagnostic = found([object(6, 1, payload.font(char_count: 3, declared: 200))], "emfplus.object.payload").first
      expect(diagnostic.message).to include("object type 6", "ID 1", "FamilyName of 200 characters")
      expect(diagnostic.record_type).to eq(0x4008)
    end

    it "flags an indexed bitmap whose palette runs past the object" do
      bitmap = payload::GRAPHICS_VERSION + [1, 2, 2, 8, 0x30000 | 8, 0, 0, 9_999].pack("V8")
      expect(messages(object(5, 4, bitmap), "emfplus.object.payload").first).to include("Palette of 9999 entries")
    end

    it "reports a continued object once, at its last chunk" do
      data = payload.font(char_count: 3, declared: 200)
      first = build.record(0x4008, flags: 0x8000 | (6 << 8) | 1, body: [data.bytesize].pack("V") + data.byteslice(0, 20))
      last = build.record(0x4008, flags: (6 << 8) | 1, body: data.byteslice(20..))
      expect(found([first, last], "emfplus.object.payload").map(&:record_type)).to eq([0x4008])
    end
  end

  describe "emfplus.image.fields" do
    def object(type, id, data) = build.object(type, id, data)

    it "accepts pixel bitmaps with an aligned stride and compressed bitmaps" do
      records = [object(5, 1, payload.bitmap_image), object(5, 2, payload.bitmap_image(bitmap_type: 1, stride: 3))]
      expect(found(records, "emfplus.image.fields")).to be_empty
    end

    it "flags a stride that is not a multiple of four, only for pixel data" do
      expect(messages(object(5, 1, payload.bitmap_image(stride: 6)), "emfplus.image.fields").first).to include("Stride 6")
    end

    it "flags an image, bitmap or metafile type outside its enumeration" do
      expect(messages(object(5, 1, payload.bitmap_image(image_type: 3, pixels: "")), "emfplus.image.fields").first)
        .to include("Type 3 is not an ImageDataType")
      expect(messages(object(5, 1, payload.bitmap_image(bitmap_type: 2)), "emfplus.image.fields").first)
        .to include("bitmap Type 2")
      expect(messages(object(5, 1, payload.metafile_image(type: 9)), "emfplus.image.fields").first).to include("metafile Type 9")
    end
  end

  describe "profiles" do
    it "reports these as errors under strict and tolerant (no tolerant_reason: a real producer was not found violating them)" do
      bad = build.stream(payload.driver_string(matrix_present: 2))
      expect(build.diagnostics(bad, "emfplus.draw.driver_string_matrix", profile: :tolerant).first.severity).to eq(:error)
    end
  end
end
