# frozen_string_literal: true

require "spec_helper"
require "emf/emr/binary/records/create_font_indirect_w"
require_relative "../../../support/font_record_helpers"

RSpec.describe Emf::Emr::Binary::Records::CreateFontIndirectW do
  include FontRecordHelpers

  it "exposes signed LOGFONT fields, flags, and unmodified UTF-16 units" do
    bytes = font_record_bytes(log_font_bytes)
    wire = described_class.read(bytes)

    expect(wire.elw.height).to eq(-18)
    expect(wire.elw.width).to eq(-2)
    expect(wire.elw.orientation).to eq(-900)
    expect(wire.elw.char_set).to eq(255)
    expect(wire.elw.facename.to_a.first(3)).to eq([0xD800, 0, 0xDC00])
    expect(wire.body.snapshot).to eq(log_font_bytes)
    expect(wire.to_binary_s).to eq(bytes)
    wire.elw.height = -42
    expect(described_class.read(wire.to_binary_s).elw.height).to eq(-42)
  end

  it "exposes Panose metadata while preserving ignored values and padding" do
    bytes = font_record_bytes(panose_font_bytes)
    wire = described_class.read(bytes)

    expect(wire.elw.log_font.weight).to eq(700)
    expect(wire.elw.fullname.to_a).to eq(Array.new(64, 66))
    expect(wire.elw.reserved).to eq(5)
    expect(wire.elw.vendor_id.to_a).to eq([65, 66, 67, 68])
    expect(wire.elw.panose.x_height).to eq(10)
    expect(wire.elw.padding.to_a).to eq([11, 12])
    expect(wire.to_binary_s).to eq(bytes)
    wire.elw.panose.weight = 99
    expect(described_class.read(wire.to_binary_s).elw.panose.weight).to eq(99)
  end

  it "zero extends partial Panose fields and retains their original encoded size" do
    body = panose_font_bytes.byteslice(0, 101)
    wire = described_class.read(font_record_bytes(body))

    expect(wire.elw.fullname.to_a.first(5)).to eq([66, 66, 66, 66, 66])
    expect(wire.elw.style.to_a).to eq(Array.new(32, 0))
    expect(wire.body.snapshot).to eq(body)
    wire.elw.log_font.height = 123
    expect(wire.to_binary_s.bytesize).to eq(113)
    wire.elw.culture = 1
    expect { wire.to_binary_s }.to raise_error(BinData::ValidityError)
  end

  it "exposes ExDv script and signed axes and preserves trailing bytes" do
    bytes = font_record_bytes(exdv_font_bytes)
    wire = described_class.read(bytes)

    expect(wire.elw.script.to_a).to eq(Array.new(32, 68))
    expect(wire.elw.design_vector.signature).to eq(0x08007664)
    expect(wire.elw.design_vector.axis_values.to_a).to eq([-123, 456])
    expect(wire.elw.trailing).to eq("\xAA\xBB\xCC\xDD".b)
    expect(wire.to_binary_s).to eq(bytes)
    wire.elw.design_vector.axis_values[0] = -789
    expect(described_class.read(wire.to_binary_s).elw.design_vector.axis_values[0]).to eq(-789)
  end

  it "round trips zero and maximum axis counts" do
    [[], (0...16).map(&:-@)].each do |axes|
      bytes = font_record_bytes(exdv_font_bytes(axes, "".b))
      expect(described_class.read(bytes).to_binary_s).to eq(bytes)
    end
  end

  it "retains the byte assignment API and reads only the declared body" do
    bytes = font_record_bytes(log_font_bytes)
    wire = described_class.new(i_type: 82, n_size: bytes.bytesize, ih_object: 7, body: log_font_bytes)
    expect(wire.to_binary_s).to eq(bytes)
    expect(described_class.read("#{bytes}suffix").to_binary_s).to eq(bytes)
    expect { described_class.read(bytes.byteslice(0...-1)) }.to raise_error(BinData::ValidityError)
  end

  it "accepts semantic constructors without reparsing font bytes" do
    wire = described_class.new(i_type: 82, n_size: 104, ih_object: 7)
    wire.body.font = Emf::Emr::Binary::LogFont.new(height: -27, facename: [65] + Array.new(31, 0))

    expect(described_class.read(wire.to_binary_s).elw.height).to eq(-27)
  end

  it "accepts semantic Panose and ExDv constructors" do
    panose = Emf::Emr::Binary::LogFontPanose.new(log_font: { height: -9 }, vendor_id: [1, 2, 3, 4], padding: [8, 9])
    extended = Emf::Emr::Binary::LogFontExDv.new(
      log_font: { width: -7 }, script: Array.new(32, 65),
      design_vector: { signature: 0x08007664, num_axes: 1, axis_values: [-999] }, trailing: "\xFE".b
    )
    [panose, extended].each do |font|
      wire = described_class.new(i_type: 82, n_size: font.num_bytes + 12, ih_object: 7)
      wire.body.font = font
      expect(described_class.read(wire.to_binary_s).elw.snapshot).to eq(font.snapshot)
    end
  end

  it "rejects invalid vector edits without discarding field values" do
    wire = described_class.read(font_record_bytes(exdv_font_bytes))
    wire.elw.design_vector.signature = 0
    expect { wire.to_binary_s }.to raise_error(BinData::ValidityError)
    wire.elw.design_vector.signature = 0x08007664
    wire.elw.design_vector.num_axes = 1
    expect { wire.to_binary_s }.to raise_error(BinData::ValidityError)
    wire.elw.design_vector.num_axes = 2
    expect(wire.to_binary_s).to eq(font_record_bytes(exdv_font_bytes))
  end

  it "rejects undersized fonts, truncated ExDv and excessive design axes" do
    ["\0" * 91, "\0" * 321, "\0" * 355, exdv_font_bytes.byteslice(0, 359),
     exdv_font_bytes.byteslice(0, 352) + [17].pack("V"),
     exdv_font_bytes.byteslice(0, 348) + [0].pack("V") + exdv_font_bytes.byteslice(352..)].each do |body|
      expect { described_class.read(font_record_bytes(body)) }.to raise_error(BinData::ValidityError)
    end
  end
end
