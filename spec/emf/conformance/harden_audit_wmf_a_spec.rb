# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Conformance WMF record-rule hardening (MS-WMF 2.3.4.8, 2.3.5.16)" do
  records = Emf::Model::Wmf::Records
  header = Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 12, number_of_objects: 16, max_record_words: 3,
                                       number_of_members: 0)

  def ids(metafile) = Emf::Conformance.check(metafile, profile: :strict).diagnostics.map(&:requirement_id)

  build = lambda do |record|
    Emf::Model::Metafile.new(format: :wmf, header: header, records: [record, records::Eof.new(offset: 100)])
  end

  describe "wmf.enum.color_usage" do
    it "ignores ColorUsage when the pattern brush style is BS_PATTERN (the clause says DIB_RGB_COLORS is used regardless)" do
      record = records::DibCreatePatternBrush.new(style: 3, color_usage: 7, target: "".b, offset: 18)
      expect(ids(build.call(record))).not_to include("wmf.enum.color_usage")
    end

    it "still rejects an out-of-range ColorUsage for BS_DIBPATTERNPT" do
      record = records::DibCreatePatternBrush.new(style: 6, color_usage: 7, target: "".b, offset: 18)
      expect(ids(build.call(record))).to include("wmf.enum.color_usage")
    end

    it "still rejects an out-of-range ColorUsage for a style other than BS_PATTERN, which is read as BS_DIBPATTERNPT" do
      record = records::DibCreatePatternBrush.new(style: 5, color_usage: 3, target: "".b, offset: 18)
      expect(ids(build.call(record))).to include("wmf.enum.color_usage")
    end
  end

  describe "wmf.flags.layout" do
    it "rejects bits the Layout enumeration (0x0000, 0x0001, 0x0008) does not define" do
      [0x2, 0x4, 0xA].each do |value|
        record = records::SetLayout.new(layout: value, reserved: 0, offset: 18)
        expect(ids(build.call(record))).to include("wmf.flags.layout"), "layout 0x#{value.to_s(16)}"
      end
    end

    it "accepts LAYOUT_LTR, LAYOUT_RTL, LAYOUT_BITMAPORIENTATIONPRESERVED and their combination" do
      [0x0, 0x1, 0x8, 0x9].each do |value|
        record = records::SetLayout.new(layout: value, reserved: 0, offset: 18)
        expect(ids(build.call(record))).not_to include("wmf.flags.layout"), "layout 0x#{value.to_s(16)}"
      end
    end
  end
end
