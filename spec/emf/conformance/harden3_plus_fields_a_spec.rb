# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# emfplus.object.fields (Brush, Pen, CustomLineCap) and emfplus.object.pen_line_fields: the enumeration and range
# clauses of MS-EMFPLUS 2.2.1 for the decoded objects.
RSpec.describe "EMF+ object field rules (Brush, Pen, CustomLineCap)" do
  let(:builder) { Emf::SpecSupport::EmfPlusBuilder }
  let(:version) { [0xDBC01002].pack("V") }
  let(:linear) { [4].pack("V") }
  let(:gradient_colors) { [0xFF000000, 0xFFFFFFFF, 0, 0].pack("V4") }
  let(:solid) { version + [0, 0xFF000000].pack("V2") }

  def findings(object_type, data, id: "emfplus.object.fields", profile: :strict)
    bytes = builder.stream(builder.object(object_type, 0, data))
    builder.diagnostics(bytes, id, profile: profile)
  end

  def pen(flags: 0, unit: 2, type: 0, optional: "".b)
    version + [type, flags, unit].pack("V3") + [1.0].pack("e") + optional + solid
  end

  def custom_cap(type: 0, flags: 0, base: 0, start: 0, finish: 0, join: 0, hot: [0.0, 0.0, 0.0, 0.0])
    version + [type].pack("V") + [flags, base].pack("V2") + [0.0].pack("e") + [start, finish, join].pack("V3") +
      [0.0, 1.0].pack("e2") + hot.pack("e4")
  end

  describe "Brush" do
    it "accepts a defined BrushType and HatchStyle" do
      expect(findings(1, version + [1, 0x34, 0xFF000000, 0xFFFFFFFF].pack("V4"))).to be_empty
    end

    it "reports an undefined BrushType" do
      expect(findings(1, version + [9, 0].pack("V2")).map(&:message)).to include(a_string_matching(/Type 9 is not a BrushType/))
    end

    it "reports an undefined HatchStyle" do
      data = version + [1, 0x35, 0xFF000000, 0xFFFFFFFF].pack("V4")
      expect(findings(1, data).map(&:message)).to include(a_string_matching(/HatchStyle 53 is not a HatchStyle/))
    end

    it "reports an undefined WrapMode and BrushDataFlags bit on a linear gradient" do
      body = [0x20, 7].pack("Vl<") + builder.rect_f + gradient_colors
      messages = findings(1, version + linear + body).map(&:message)
      expect(messages).to include(a_string_matching(/WrapMode 7/), a_string_matching(/BrushDataFlags 0x20/))
    end

    it "accepts every WrapMode value on a linear gradient" do
      (0..4).each do |mode|
        body = [0, mode].pack("Vl<") + builder.rect_f + gradient_colors
        expect(findings(1, version + linear + body)).to be_empty
      end
    end
  end

  describe "Pen" do
    it "accepts a pen with every optional enumeration in domain" do
      optional = [1, 0xF0, 2].pack("l<3") + [10.0].pack("e") + [5, 3].pack("l<2") + [0.0].pack("e") + [4].pack("l<")
      expect(findings(2, pen(flags: 0x2 | 0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x80 | 0x200, optional: optional))).to be_empty
    end

    it "reports a nonzero pen Type, an undefined PenUnit and an undefined flag bit" do
      messages = findings(2, pen(type: 1, unit: 7, flags: 0x2000)).map(&:message)
      expect(messages).to include(a_string_matching(/Type is 1, MUST be 0/), a_string_matching(/PenUnit 7/),
                                  a_string_matching(/PenDataFlags 0x2000/))
    end

    it "reports an undefined StartCap and PenAlignment" do
      messages = findings(2, pen(flags: 0x2 | 0x200, optional: [99, 9].pack("l<2"))).map(&:message)
      expect(messages).to include(a_string_matching(/StartCap 99/), a_string_matching(/PenAlignment 9/))
    end

    it "reports Join, LineStyle and DashedLineCapType under the separately waived rule id" do
      data = pen(flags: 0x8 | 0x20 | 0x40, optional: [9, 6, 1].pack("l<3"))
      expect(findings(2, data, id: "emfplus.object.pen_line_fields").map(&:message))
        .to include(a_string_matching(/Join 9/), a_string_matching(/LineStyle 6/), a_string_matching(/DashedLineCapType 1/))
      expect(findings(2, data, id: "emfplus.object.pen_line_fields", profile: :tolerant).map(&:severity).uniq).to eq([:warning])
    end

    it "reports a bad nested custom cap" do
      cap = custom_cap(type: 5)
      data = pen(flags: 0x800, optional: [cap.bytesize].pack("V") + cap)
      expect(findings(2, data).map(&:message)).to include(a_string_matching(/CustomLineCap Type 5/))
    end
  end

  describe "CustomLineCap" do
    it "accepts a default cap with defined fields" do
      expect(findings(9, custom_cap(base: 0x14, start: 2, finish: 0xFF, join: 3))).to be_empty
    end

    it "reports an undefined Type" do
      expect(findings(9, custom_cap(type: 2)).map(&:message)).to include(a_string_matching(/Type 2 is not a CustomLineCapDataType/))
    end

    it "reports undefined caps, join, flag bits and non-zero hot spots" do
      messages = findings(9, custom_cap(flags: 0x8, base: 7, start: 99, join: 8, hot: [1.0, 0.0, 0.0, 2.0])).map(&:message)
      expect(messages).to include(a_string_matching(/CustomLineCapDataFlags 0x8/), a_string_matching(/BaseCap 7/),
                                  a_string_matching(/StrokeStartCap 99/), a_string_matching(/StrokeJoin 8/),
                                  a_string_matching(/FillHotSpot is \{1\.0, 0\.0\}/), a_string_matching(/StrokeHotSpot/))
    end
  end

  it "keeps strict findings an error and rejects the file" do
    bytes = builder.stream(builder.object(1, 0, version + [9, 0].pack("V2")))
    expect(Emf::Conformance.check(bytes, profile: :strict)).not_to be_valid
  end
end
