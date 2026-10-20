# frozen_string_literal: true

require "spec_helper"

%w[argb point point_f point_r relative_coordinate rect rect_f transform_matrix
   palette character_range language_identifier graphics_version blend_colors
   blend_factors focus_scale_data path_point_type path_point_type_rle].each do |name|
  require "emf/emf_plus/records/primitives/#{name}"
end

module EmfPlusPrimitivesSpec
  Prim = Emf::EmfPlus::Records::Primitives
end

RSpec.describe "EMF+ primitive structures (MS-EMFPLUS 2.2.2)" do
  def self.round_trips(klass, wire, size)
    it "re-encodes byte-identically (#{size} bytes)" do
      parsed = klass.read(wire)
      expect(parsed.to_binary_s).to eq(wire)
      expect(parsed.num_bytes).to eq(size)
    end
  end

  describe "EmfPlusARGB (2.2.2.1)" do
    let(:wire) { [0x11, 0x22, 0x33, 0xFF].pack("C4") }

    it "stores bytes as blue, green, red, alpha" do
      argb = EmfPlusPrimitivesSpec::Prim::ARGB.read(wire)
      expect([argb.blue, argb.green, argb.red, argb.alpha]).to eq([0x11, 0x22, 0x33, 0xFF])
    end

    it "is the little-endian dword 0xAARRGGBB" do
      expect(wire.unpack1("V")).to eq(0xFF332211)
    end

    it "decodes the byte extremes unsigned" do
      argb = EmfPlusPrimitivesSpec::Prim::ARGB.read("\xFF\x00\x80\x00".b)
      expect([argb.blue, argb.green, argb.red, argb.alpha]).to eq([255, 0, 128, 0])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::ARGB, [0x11, 0x22, 0x33, 0xFF].pack("C4"), 4)

    it "rejects truncated input" do
      expect { EmfPlusPrimitivesSpec::Prim::ARGB.read("\x01\x02\x03".b).alpha }.to raise_error(EOFError)
    end
  end

  describe "EmfPlusPoint (2.2.2.35)" do
    it "decodes signed 16-bit coordinates at the extremes" do
      point = EmfPlusPrimitivesSpec::Prim::Point.read([-32_768, 32_767].pack("s<2"))
      expect([point.x, point.y]).to eq([-32_768, 32_767])
    end

    it "decodes 0xFFFF as -1, not 65535" do
      expect(EmfPlusPrimitivesSpec::Prim::Point.read("\xFF\xFF\x01\x00".b).x).to eq(-1)
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::Point, [-32_768, 32_767].pack("s<2"), 4)
  end

  describe "EmfPlusPointF (2.2.2.36)" do
    let(:wire) { [1.5, -2.25].pack("e2") }

    it "decodes little-endian 32-bit floats" do
      point = EmfPlusPrimitivesSpec::Prim::PointF.read(wire)
      expect([point.x, point.y]).to eq([1.5, -2.25])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::PointF, [1.5, -2.25].pack("e2"), 8)
  end

  describe "EmfPlusInteger7 / EmfPlusInteger15 (2.2.2.21, 2.2.2.22)" do
    def coordinate(raw) = EmfPlusPrimitivesSpec::Prim::RelativeCoordinate.read(raw.b)

    {
      "\x00" => 0, "\x3F" => 63, "\x40" => -64, "\x7F" => -1
    }.each do |raw, value|
      it "reads 7-bit #{raw.unpack1('H*')} as #{value}" do
        c = coordinate(raw)
        expect([c.to_i, c.wide?]).to eq([value, false])
      end
    end

    {
      "\x80\x00" => 0, "\xBF\xFF" => 16_383, "\xC0\x00" => -16_384,
      "\xFF\xFF" => -1, "\x80\x40" => 64, "\x81\x00" => 256
    }.each do |raw, value|
      it "reads 15-bit #{raw.unpack1('H*')} as #{value}, high byte first" do
        c = coordinate(raw)
        expect([c.to_i, c.wide?]).to eq([value, true])
      end
    end

    it "consumes one byte for 7-bit and two for 15-bit" do
      expect(coordinate("\x05").num_bytes).to eq(1)
      expect(coordinate("\x80\x05").num_bytes).to eq(2)
    end

    ["\x05", "\xC0\x00", "\x40"].each do |raw|
      it "re-encodes #{raw.unpack1('H*')} at its original width" do
        expect(coordinate(raw).to_binary_s).to eq(raw.b)
      end
    end
  end

  describe "EmfPlusPointR (2.2.2.37)" do
    it "allows axes of different widths" do
      point = EmfPlusPrimitivesSpec::Prim::PointR.read("\x7F\xC0\x00".b)
      expect([point.x.to_i, point.y.to_i]).to eq([-1, -16_384])
      expect(point.num_bytes).to eq(3)
    end

    it "reads a 15-bit x followed by a 7-bit y" do
      point = EmfPlusPrimitivesSpec::Prim::PointR.read("\x80\x0A\x40".b)
      expect([point.x.to_i, point.y.to_i]).to eq([10, -64])
    end

    ["\x7F\xC0\x00", "\x80\x0A\x40", "\x01\x02"].each do |raw|
      it "re-encodes #{raw.unpack1('H*')} byte-identically" do
        expect(EmfPlusPrimitivesSpec::Prim::PointR.read(raw.b).to_binary_s).to eq(raw.b)
      end
    end
  end

  describe "EmfPlusRect (2.2.2.39)" do
    let(:wire) { [-32_768, 5, 32_767, -1].pack("s<4") }

    it "decodes signed 16-bit x, y, width, height" do
      rect = EmfPlusPrimitivesSpec::Prim::Rect.read(wire)
      expect([rect.x, rect.y, rect.width, rect.height]).to eq([-32_768, 5, 32_767, -1])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::Rect, [-32_768, 5, 32_767, -1].pack("s<4"), 8)
  end

  describe "EmfPlusRectF (2.2.2.40)" do
    let(:wire) { [-1.5, 2.0, 3.25, 0.5].pack("e4") }

    it "decodes four little-endian floats" do
      rect = EmfPlusPrimitivesSpec::Prim::RectF.read(wire)
      expect([rect.x, rect.y, rect.width, rect.height]).to eq([-1.5, 2.0, 3.25, 0.5])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::RectF, [-1.5, 2.0, 3.25, 0.5].pack("e4"), 16)
  end

  describe "EmfPlusTransformMatrix (2.2.2.47)" do
    let(:values) { [1.0, 0.5, -0.5, 2.0, 10.0, -20.0] }

    it "decodes m11, m12, m21, m22, dx, dy in order" do
      m = EmfPlusPrimitivesSpec::Prim::TransformMatrix.read(values.pack("e6"))
      expect([m.m11, m.m12, m.m21, m.m22, m.dx, m.dy]).to eq(values)
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::TransformMatrix, [1.0, 0.5, -0.5, 2.0, 10.0, -20.0].pack("e6"), 24)
  end

  describe "EmfPlusPalette (2.2.2.28)" do
    let(:wire) { [0x3, 2].pack("V2") + [1, 2, 3, 4, 5, 6, 7, 8].pack("C8") }

    it "decodes style flags, count and ARGB entries" do
      palette = EmfPlusPrimitivesSpec::Prim::Palette.read(wire)
      expect(palette.palette_style_flags).to eq(0x3)
      expect(palette.palette_count).to eq(2)
      expect(palette.palette_entries.map { |e| [e.blue, e.green, e.red, e.alpha] })
        .to eq([[1, 2, 3, 4], [5, 6, 7, 8]])
    end

    it "keeps the PaletteStyle bits (2.1.2.5) HasAlpha, GrayScale, Halftone" do
      flags = [0x1, 0x2, 0x4].map { |f| EmfPlusPrimitivesSpec::Prim::Palette.read([f, 0].pack("V2")).palette_style_flags }
      expect(flags).to eq([1, 2, 4])
    end

    it "accepts an empty palette" do
      palette = EmfPlusPrimitivesSpec::Prim::Palette.read([0, 0].pack("V2"))
      expect([palette.palette_entries.length, palette.num_bytes]).to eq([0, 8])
    end

    it "sizes as 8 + 4 per entry and re-encodes identically" do
      palette = EmfPlusPrimitivesSpec::Prim::Palette.read(wire)
      expect([palette.num_bytes, palette.to_binary_s]).to eq([16, wire])
    end

    it "rejects a count larger than the data" do
      expect { EmfPlusPrimitivesSpec::Prim::Palette.read([0, 3].pack("V2") + ("\0".b * 4)).palette_entries.to_a }
        .to raise_error(EOFError)
    end
  end

  describe "EmfPlusCharacterRange (2.2.2.8)" do
    it "decodes signed 32-bit first position and length" do
      range = EmfPlusPrimitivesSpec::Prim::CharacterRange.read([-2_147_483_648, 2_147_483_647].pack("l<2"))
      expect([range.first_position, range.range_length]).to eq([-2_147_483_648, 2_147_483_647])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::CharacterRange, [3, 7].pack("l<2"), 8)
  end

  describe "EmfPlusLanguageIdentifier (2.2.2.23)" do
    it "splits a 6-bit sublanguage above a 10-bit primary language" do
      lang = EmfPlusPrimitivesSpec::Prim::LanguageIdentifier.read([0x0409].pack("V"))
      expect([lang.primary_language_id, lang.sub_language_id]).to eq([0x09, 0x01])
    end

    it "decodes the field maxima" do
      lang = EmfPlusPrimitivesSpec::Prim::LanguageIdentifier.read([0xFFFF].pack("V"))
      expect([lang.primary_language_id, lang.sub_language_id]).to eq([0x3FF, 0x3F])
    end

    it "ignores bits above the 16-bit identifier" do
      lang = EmfPlusPrimitivesSpec::Prim::LanguageIdentifier.read([0xABCD0409].pack("V"))
      expect([lang.primary_language_id, lang.sub_language_id]).to eq([0x09, 0x01])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::LanguageIdentifier, [0xABCD0409].pack("V"), 4)
  end

  describe "EmfPlusGraphicsVersion (2.2.2.19)" do
    it "splits the 0xDBC01 signature from the 12-bit version" do
      version = EmfPlusPrimitivesSpec::Prim::GraphicsVersion.read([0xDBC01002].pack("V"))
      expect([version.metafile_signature, version.graphics_version]).to eq([0xDBC01, 2])
    end

    it "reports GraphicsVersion1 (0x1)" do
      expect(EmfPlusPrimitivesSpec::Prim::GraphicsVersion.read([0xDBC01001].pack("V")).graphics_version).to eq(1)
    end

    it "exposes a foreign signature rather than hiding it" do
      expect(EmfPlusPrimitivesSpec::Prim::GraphicsVersion.read([0x12345001].pack("V")).metafile_signature).to eq(0x12345)
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::GraphicsVersion, [0xDBC01002].pack("V"), 4)
  end

  describe "EmfPlusBlendColors (2.2.2.4)" do
    let(:wire) { [2].pack("V") + [0.0, 1.0].pack("e2") + [1, 2, 3, 4, 5, 6, 7, 8].pack("C8") }

    it "decodes positions then colors" do
      blend = EmfPlusPrimitivesSpec::Prim::BlendColors.read(wire)
      expect(blend.blend_positions.to_a).to eq([0.0, 1.0])
      expect(blend.blend_colors.map(&:alpha)).to eq([4, 8])
    end

    it "sizes as 4 + 8 per position and re-encodes identically" do
      blend = EmfPlusPrimitivesSpec::Prim::BlendColors.read(wire)
      expect([blend.num_bytes, blend.to_binary_s]).to eq([20, wire])
    end

    it "accepts zero positions" do
      expect(EmfPlusPrimitivesSpec::Prim::BlendColors.read([0].pack("V")).num_bytes).to eq(4)
    end
  end

  describe "EmfPlusBlendFactors (2.2.2.5)" do
    let(:wire) { [2].pack("V") + [0.0, 1.0].pack("e2") + [0.25, 0.75].pack("e2") }

    it "decodes positions then factors" do
      blend = EmfPlusPrimitivesSpec::Prim::BlendFactors.read(wire)
      expect(blend.blend_positions.to_a).to eq([0.0, 1.0])
      expect(blend.blend_factors.to_a).to eq([0.25, 0.75])
    end

    it "sizes as 4 + 8 per position and re-encodes identically" do
      blend = EmfPlusPrimitivesSpec::Prim::BlendFactors.read(wire)
      expect([blend.num_bytes, blend.to_binary_s]).to eq([20, wire])
    end
  end

  describe "EmfPlusFocusScaleData (2.2.2.18)" do
    let(:wire) { [2].pack("V") + [0.5, 0.25].pack("e2") }

    it "decodes the count and the x and y scales" do
      data = EmfPlusPrimitivesSpec::Prim::FocusScaleData.read(wire)
      expect([data.focus_scale_count, data.focus_scale_x, data.focus_scale_y]).to eq([2, 0.5, 0.25])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::FocusScaleData, [2].pack("V") + [0.5, 0.25].pack("e2"), 12)
  end

  describe "EmfPlusPathPointType (2.2.2.31)" do
    it "splits flags (high nibble) from type (low nibble)" do
      point = EmfPlusPrimitivesSpec::Prim::PathPointType.read("\xA3".b)
      expect([point.flags, point.type]).to eq([0xA, 0x3])
    end

    it "decodes the nibble extremes" do
      expect(EmfPlusPrimitivesSpec::Prim::PathPointType.read("\x00".b).flags).to eq(0)
      point = EmfPlusPrimitivesSpec::Prim::PathPointType.read("\xFF".b)
      expect([point.flags, point.type]).to eq([0xF, 0xF])
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::PathPointType, "\xA3".b, 1)
  end

  describe "EmfPlusPathPointTypeRLE (2.2.2.32)" do
    it "reads the Bezier bit, 6-bit run count and the point type" do
      rle = EmfPlusPrimitivesSpec::Prim::PathPointTypeRLE.read("\xBF\x03".b)
      expect([rle.bezier?, rle.run_count, rle.point_type.type]).to eq([true, 0x3F, 3])
    end

    it "reports a line run when the Bezier bit is clear" do
      rle = EmfPlusPrimitivesSpec::Prim::PathPointTypeRLE.read("\x05\x81".b)
      expect([rle.bezier?, rle.run_count]).to eq([false, 5])
      expect([rle.point_type.flags, rle.point_type.type]).to eq([8, 1])
    end

    it "does not fold the reserved bit into the run count" do
      expect(EmfPlusPrimitivesSpec::Prim::PathPointTypeRLE.read("\xC1\x00".b).run_count).to eq(1)
    end

    round_trips(EmfPlusPrimitivesSpec::Prim::PathPointTypeRLE, "\xBF\x03".b, 2)
  end
end
