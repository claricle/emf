# frozen_string_literal: true

require "spec_helper"
require_relative "../support/control_buffers_cases"

RSpec.describe "Emf::Conformance control-record buffer rules" do
  let(:support) { Emf::SpecSupport::ControlBuffersCases }
  let(:ids) { support.cases.keys }

  def reports(bytes, profile: :strict) = Emf::Conformance.check(bytes, profile: profile)

  let(:own) { /\Aemf\.(header\.(description_terminator|buffers_overlap|pixel_format_(size|content))|eof\.palette_)/ }

  def fired(bytes, own: self.own) = reports(bytes).diagnostics.map(&:requirement_id).grep(own).uniq.sort

  it "registers every rule with a crafted case" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(own)
    expect(registered).to match_array(ids)
  end

  it "leaves a well-formed header with description, pixel format and an EOF palette alone" do
    bytes = support.file(header: support.header)
    expect(fired(bytes)).to be_empty
    expect(reports(bytes).errors).to be_empty
  end

  it "leaves a header without description or pixel format alone" do
    bytes = support.file(header: support.header(description: "".b, pixel_format: "".b, off_description: 0,
                                                off_pixel_format: 0, n_pal_entries: 0),
                         eof: support.eof(entries: 0))
    expect(fired(bytes)).to be_empty
  end

  it "accepts the GDI layout of an EOF palette at offset 16 and an empty EOF" do
    expect(fired(support.file(header: support.header(n_pal_entries: 0), eof: support.eof(entries: 0)))).to be_empty
    expect(fired(support.file(header: support.header(n_pal_entries: 3), eof: support.eof(entries: 3)))).to be_empty
  end

  describe "each rule" do
    Emf::SpecSupport::ControlBuffersCases.cases.each do |id, bytes|
      it "#{id} fires on its crafted file and on nothing else" do
        expect(fired(bytes)).to eq([id])
        diagnostic = reports(bytes).diagnostics.find { |d| d.requirement_id == id }
        expect(diagnostic.spec_citation).to match(/\AMS-EMF \d+(\.\d+)+\z/)
      end

      it "#{id} is tolerated under the tolerant profile" do
        expect(reports(bytes, profile: :tolerant).errors).to be_empty
      end
    end
  end

  describe "rule details" do
    it "reports a palette that overlaps SizeLast" do
      bytes = support.file(header: support.header(n_pal_entries: 3), eof: support.eof(entries: 2, count: 3))
      expect(reports(bytes).diagnostics.map(&:message).join).to include("does not fit before SizeLast")
    end

    it "reports a palette offset inside the fixed part" do
      bytes = support.file(header: support.header(n_pal_entries: 2), eof: support.eof(offset: 8))
      expect(reports(bytes).diagnostics.map(&:message).join).to include("inside the 16-byte fixed part")
    end

    it "ignores pixel-format fields in an 88-byte header" do
      bytes = Emf::SpecSupport::CraftedEmf.build
      bytes[88, 0] = ""
      expect(fired(bytes)).to be_empty
    end

    it "reports each of nSize, nVersion, iPixelType and the double-buffer/GDI flags" do
      pfd = [41, 2, 0x11, 3].pack("vvVC") + ("\0".b * 31)
      messages = reports(support.file(header: support.header(pixel_format: pfd))).diagnostics.map(&:message).join("\n")
      expect(messages).to include("nSize is 41", "nVersion is 2", "iPixelType is 3", "PFD_DOUBLEBUFFER and PFD_SUPPORT_GDI")
    end

    it "still reads the description when it is exactly terminated" do
      expect(support.header(description: support.utf16("a\0")).bytesize).to be > 100
      expect(fired(support.file(header: support.header(description: support.utf16("a\0"))))).to be_empty
    end
  end
end
