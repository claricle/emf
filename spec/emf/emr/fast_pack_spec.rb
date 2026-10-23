# frozen_string_literal: true

require "spec_helper"

# Write side of the layout shared with FastFill (Binary::FastFill#pack),
# reached through WireAdapter#to_binary_s.
RSpec.describe Emf::Emr::Binary::FastFill, "#pack" do
  codes = Emf::Emr::Binary::TypeCodes
  # [type code, fixed size, field edit]
  types = {
    "SelectObject" => [codes::SELECTOBJECT, 12, ->(w) { w.ih_object = 7 }],
    "DeleteObject" => [codes::DELETEOBJECT, 12, ->(w) { w.ih_object = 7 }],
    "MoveToEx" => [codes::MOVETOEX, 16, ->(w) { w.origin.x = -7 }],
    "LineTo" => [codes::LINETO, 16, ->(w) { w.origin.y = -7 }],
    "CreateBrushIndirect" => [codes::CREATEBRUSHINDIRECT, 24, ->(w) { w.color.green = 7 }],
    "SetBkColor" => [codes::SETBKCOLOR, 12, ->(w) { w.color.red = 7 }],
    "SetPixelV" => [codes::SETPIXELV, 20, ->(w) { w.ptl_pixel.x = -7 }],
    "CreatePen" => [codes::CREATEPEN, 28, ->(w) { w.width.y = -7 }],
    "SetBkMode" => [codes::SETBKMODE, 12, ->(w) { w.bk_mode = 7 }],
    "SetTextColor" => [codes::SETTEXTCOLOR, 12, ->(w) { w.color.blue = 7 }],
    "SetTextAlign" => [codes::SETTEXTALIGN, 12, ->(w) { w.text_align_mode = 7 }],
    "Ellipse" => [codes::ELLIPSE, 24, ->(w) { w.rcl_box.bottom = -7 }],
    "SetViewportOrgEx" => [codes::SETVIEWPORTORGEX, 16, ->(w) { w.origin.x = -7 }],
    "RestoreDc" => [codes::RESTOREDC, 12, ->(w) { w.saved_dc = -7 }],
    "SetWorldTransform" => [codes::SETWORLDTRANSFORM, 32, ->(w) { w.xform.dy = -7.5 }],
    "ModifyWorldTransform" => [codes::MODIFYWORLDTRANSFORM, 36, ->(w) { w.modify_mode = 7 }],
    "SetMapMode" => [codes::SETMAPMODE, 12, ->(w) { w.map_mode = 7 }],
    "SetWindowExtEx" => [codes::SETWINDOWEXTEX, 16, ->(w) { w.extent.cx = -7 }],
    "SetWindowOrgEx" => [codes::SETWINDOWORGEX, 16, ->(w) { w.origin.y = -7 }],
    "SetViewportExtEx" => [codes::SETVIEWPORTEXTEX, 16, ->(w) { w.extent.cy = -7 }],
    "SetPolyFillMode" => [codes::SETPOLYFILLMODE, 12, ->(w) { w.poly_fill_mode = 7 }],
    "SetRop2" => [codes::SETROP2, 12, ->(w) { w.rop2 = 7 }],
    "SetStretchBltMode" => [codes::SETSTRETCHBLTMODE, 12, ->(w) { w.stretch_mode = 7 }],
    "SetBrushOrgEx" => [codes::SETBRUSHORGEX, 16, ->(w) { w.ptl_origin.x = -7 }],
    "SaveDc" => [codes::SAVEDC, 8, ->(w) { w.n_size = 16 }],
    "BeginPath" => [codes::BEGINPATH, 8, ->(w) { w.n_size = 16 }],
    "EndPath" => [codes::ENDPATH, 8, ->(w) { w.n_size = 16 }],
    "CloseFigure" => [codes::CLOSEFIGURE, 8, ->(w) { w.n_size = 16 }],
    "FillPath" => [codes::FILLPATH, 24, ->(w) { w.rcl_bounds.left = -7 }],
    "StrokeAndFillPath" => [codes::STROKEANDFILLPATH, 24, ->(w) { w.rcl_bounds.top = -7 }],
    "StrokePath" => [codes::STROKEPATH, 24, ->(w) { w.rcl_bounds.right = -7 }],
    "Rectangle" => [codes::RECTANGLE, 24, ->(w) { w.rcl_box.bottom = -7 }],
    "IntersectClipRect" => [codes::INTERSECTCLIPRECT, 24, ->(w) { w.rcl_clip.left = -7 }],
    "ExcludeClipRect" => [codes::EXCLUDECLIPRECT, 24, ->(w) { w.rcl_clip.top = -7 }],
    "SetMiterLimit" => [codes::SETMITERLIMIT, 12, ->(w) { w.miter_limit = 7.5 }],
    "SetIcmMode" => [codes::SETICMMODE, 12, ->(w) { w.mode = 7 }],
    "SetLayout" => [codes::SETLAYOUT, 12, ->(w) { w.mode = 7 }]
  }

  extras = [0, 4, 8].freeze

  def record_bytes(type, size, total)
    body = Array.new(size - 8) { |i| (0x80 + (i * 37)) & 0xFF }.pack("C*")
    [type, total].pack("VV") + body + ("\xAB".b * (total - size))
  end

  # Reference: BinData's own serialisation with the suffix rule applied.
  def reference(klass, bytes, edit)
    wire = klass.read(bytes)
    edit&.call(wire)
    suffix = Emf::Model::Emr::Records::WireAdapter.suffix_of(bytes, klass.read(bytes))
    out = wire.to_binary_s
    return out if suffix.empty?

    out[4, 4] = [out.bytesize + suffix.bytesize].pack("V")
    out + suffix
  end

  def adapter_for(type, bytes)
    wire, suffix = described_class.for(type).call(bytes)
    Emf::Model::Emr::Records::WireAdapter.new(wire: wire, suffix: suffix)
  end

  it "covers every fast-fill type" do
    enabled = described_class.const_get(:BY_TYPE).keys
    expect(types.values.map(&:first)).to match_array(enabled)
  end

  float_types = %w[SetWorldTransform ModifyWorldTransform SetMiterLimit].freeze

  types.each do |name, (type, size, edit)|
    describe name do
      let(:klass) { Emf::Emr::Binary::Records.const_get(name) }

      extras.each do |extra|
        context "with #{extra} bytes beyond the layout" do
          let(:bytes) { record_bytes(type, size, size + extra) }
          let(:record) { adapter_for(type, bytes) }

          if float_types.include?(name)
            it "leaves the float layout to BinData and emits the original bytes" do
              expect(described_class.for(type).pack(record.wire)).to be_nil
              expect(record.to_binary_s).to eq(bytes)
            end
          else
            it "emits the original bytes when unedited, without BinData serialisation" do
              expect(record.wire).not_to receive(:do_write)
              expect(record.to_binary_s).to eq(bytes)
            end
          end

          it "matches BinData after an edit" do
            edit.call(record.wire)
            expect(record.to_binary_s).to eq(reference(klass, bytes, edit))
            # a bare nSize edit is overwritten by the suffix rewrite when a suffix exists
            expect(record.to_binary_s).not_to eq(bytes) unless size == 8 && extra.positive?
          end
        end
      end
    end
  end

  {
    "SelectObject" => [codes::SELECTOBJECT, 12, ->(w) { w.ih_object = 2**40 }],
    "DeleteObject" => [codes::DELETEOBJECT, 12, ->(w) { w.ih_object = -3 }],
    "MoveToEx" => [codes::MOVETOEX, 16, ->(w) { w.origin.x = -(2**40) }],
    "LineTo" => [codes::LINETO, 16, ->(w) { w.origin.y = 2**40 }],
    "CreateBrushIndirect" => [codes::CREATEBRUSHINDIRECT, 24, ->(w) { w.color.red = 999 }]
  }.each do |name, (type, size, edit)|
    it "#{name} matches BinData's clamping after an out-of-range edit" do
      bytes = record_bytes(type, size, size)
      record = adapter_for(type, bytes)
      edit.call(record.wire)
      klass = Emf::Emr::Binary::Records.const_get(name)
      expect(record.to_binary_s).to eq(reference(klass, bytes, edit))
    end
  end

  it "reflects consecutive edits" do
    bytes = record_bytes(codes::MOVETOEX, 16, 24)
    record = adapter_for(codes::MOVETOEX, bytes)
    record.wire.origin.x = -7
    expect(record.to_binary_s).to eq(reference(Emf::Emr::Binary::Records::MoveToEx, bytes, ->(w) { w.origin.x = -7 }))
    record.wire.origin.y = 9
    both = lambda do |w|
      w.origin.x = -7
      w.origin.y = 9
    end
    expect(record.to_binary_s).to eq(reference(Emf::Emr::Binary::Records::MoveToEx, bytes, both))
  end

  mode_word = [1].pack("V").freeze
  {
    "quiet NaN" => 0x7fc00000, "signalling NaN" => 0x7fa00001, "NaN with low payload" => 0x7f800001,
    "negative NaN payload" => 0xffc12345, "-0.0" => 0x80000000, "denormal" => 0x00000001,
    "largest denormal" => 0x007fffff, "+Inf" => 0x7f800000, "-Inf" => 0xff800000
  }.each do |label, bits|
    float_types.each do |name|
      it "#{name} writes #{label} identically to the input bytes" do
        type, size, = types.fetch(name)
        floats = name == "SetMiterLimit" ? 1 : 6
        head = [type, size].pack("VV")
        body = name == "ModifyWorldTransform" ? ([bits] * 6).pack("V*") + mode_word : ([bits] * floats).pack("V*")
        bytes = head + body
        bytes += "\x01".b * (size - bytes.bytesize)
        expect(adapter_for(type, bytes).to_binary_s).to eq(bytes)
      end
    end
  end

  it "drops retained NaN bits when the float is reassigned" do
    type, size, = types.fetch("SetMiterLimit")
    bytes = [type, size, 0x7fa00001].pack("VVV")
    record = adapter_for(type, bytes)
    record.wire.miter_limit = 1.5
    expect(record.to_binary_s).to eq([type, size].pack("VV") + [1.5].pack("e"))
  end

  it "leaves other wire classes to BinData" do
    expect(described_class.for_class(Emf::Emr::Binary::Records::Eof)).to be_nil
  end

  it "round-trips a real fixture byte for byte through Emf.serialize" do
    bytes = File.binread("spec/fixtures/emf/test-031.emf")
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end
end
