# frozen_string_literal: true

require "spec_helper"
require_relative "../support/bitmap_misc_cases"
require_relative "../support/deferred_cases"

RSpec.describe "Emf::Conformance comment, escape, OpenGL and opaque-record rules" do
  let(:support) { Emf::SpecSupport::BitmapMiscCases }
  let(:cases) { support.comment_cases.merge(support.escape_cases).merge(Emf::SpecSupport::DeferredCases.comment_cases) }

  def fired(bytes, profile: :strict)
    ids = Emf::Conformance.check(bytes, profile: profile).diagnostics.map(&:requirement_id)
    ids.grep(/\Aemf\.(comment|escape|opengl|opaque)\./).reject { |id| id == "emf.comment.data_size" }.uniq.sort
  end

  it "registers every rule with a crafted case" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.(comment|escape|opengl|opaque)\./)
    expect(registered - %w[emf.comment.data_size emf.opaque.text_arrays]).to match_array(cases.keys)
  end

  it "leaves well-formed comment, escape, OpenGL and opaque records alone" do
    support.clean_misc.each_with_index do |record, i|
      expect(fired(support.file(record))).to be_empty, "clean record #{i}"
    end
  end

  describe "each rule" do
    Emf::SpecSupport::BitmapMiscCases.comment_cases.merge(Emf::SpecSupport::BitmapMiscCases.escape_cases)
                                     .merge(Emf::SpecSupport::DeferredCases.comment_cases).each do |id, (bytes, expected)|
      it "#{id} fires on its crafted file and on nothing else" do
        expect(fired(bytes)).to eq(expected)
        diagnostic = Emf::Conformance.check(bytes).diagnostics.find { |d| d.requirement_id == id }
        expect(diagnostic.spec_citation).to match(/\AMS-(EMF|WMF) \d+(\.\d+)+\z/)
        expect(diagnostic.offset).to eq(88)
      end
    end
  end

  describe "comment detail" do
    it "checks every EmrFormat of a MULTIFORMATS comment" do
      format = [0x464D4520, 1, 8, 28 + 16].pack("V4")
      rect = [0, 0, 1, 1].pack("l<4")
      good = support.public_comment(0x40000004, rect + [1].pack("V") + format + "datadata".b)
      bad = support.public_comment(0x40000004, rect + [1].pack("V") + [0x464D4520, 1, 80, 44].pack("V4") + "datadata".b)
      expect(fired(support.file(good))).to be_empty
      expect(fired(support.file(bad))).to eq(%w[emf.comment.public_payload])
    end

    it "leaves valid MULTIFORMATS formats, group descriptions and colour spaces alone" do
      (Emf::SpecSupport::DeferredCases.clean_comments + support.clean_misc).each_with_index do |record, i|
        expect(fired(support.file(record))).to be_empty, "clean record #{i}"
      end
    end

    it "reads the signature and EPS version of every EmrFormat, not just the first" do
      rect = [0, 0, 1, 1].pack("l<4")
      formats = [[0x464D4520, 1, 4, 28 + 32], [0x46535045, 7, 4, 28 + 36]].map { |f| f.pack("V4") }.join
      comment = support.public_comment(0x40000004, rect + [2].pack("V") + formats + "dataEPSF".b)
      expect(fired(support.file(comment))).to eq(%w[emf.comment.multiformats_eps_version])
    end

    it "accepts a description whose nDescription counts the terminator or not, and flags a missing one" do
      deferred = Emf::SpecSupport::DeferredCases
      expect(fired(support.file(deferred.group(1, "A\0\0\0".b)))).to be_empty
      expect(fired(support.file(deferred.group(2, "A\0\0\0".b)))).to be_empty
      expect(fired(support.file(deferred.group(1, "A\0".b)))).to eq(%w[emf.comment.group_description])
    end

    it "downgrades nothing but the PDF-signature finding under the tolerant profile" do
      cases = Emf::SpecSupport::DeferredCases.comment_cases
      signature = Emf::Conformance.check(cases.fetch("emf.comment.multiformats_signature").first, profile: :tolerant)
      eps = Emf::Conformance.check(cases.fetch("emf.comment.multiformats_eps_version").first, profile: :tolerant)
      expect(signature.errors).to be_empty
      expect(eps.errors.map(&:requirement_id)).to eq(%w[emf.comment.multiformats_eps_version])
    end

    it "checks the LogColorSpace Signature, Type and Intent of CREATECOLORSPACE and its wide form" do
      deferred = Emf::SpecSupport::DeferredCases
      expect(fired(support.file(deferred.color_space(signature: 1, type: 5, intent: 3)))).to eq(%w[emf.opaque.colorspace_fields])
      messages = Emf::Conformance.check(support.file(deferred.color_space(signature: 1, type: 5, intent: 3))).diagnostics.map(&:message)
      expect(messages.grep(/LogColorSpace/).size).to eq(3)
      logical = deferred.color_space(version: 9).byteslice(12..).ljust(588, "\0".b)
      wide = Emf::SpecSupport::CraftedEmf.record(122, [1].pack("V") + logical + ("\0".b * 8))
      expect(fired(support.file(wide))).to eq(%w[emf.opaque.colorspace_fields])
    end

    it "reports a BEGINGROUP that is never closed, as a warning when tolerant" do
      bytes = support.cases.fetch("emf.comment.group_unclosed").first
      diagnostic = Emf::Conformance.check(bytes, profile: :tolerant).diagnostics.find { |d| d.requirement_id == "emf.comment.group_unclosed" }
      expect([diagnostic.offset, diagnostic.severity]).to eq([88, :warning])
    end

    it "pairs nested groups" do
      nested = (support.public_comment(2, support.group_rect) * 2) + (support.public_comment(3) * 2)
      expect(fired(support.file(nested))).to be_empty
    end

    it "does not touch EMF+ comments" do
      bytes = support.file(support.comment("EMF+".b + ("\0".b * 4)))
      expect(fired(bytes)).to be_empty
    end
  end

  describe "downgrades" do
    it "reports the record-size rules as warnings under the tolerant profile" do
      %w[emf.escape.record_size emf.opengl.record_size emf.opaque.fixed_size].each do |id|
        diagnostic = Emf::Conformance.check(cases.fetch(id).first, profile: :tolerant).diagnostics.find { |d| d.requirement_id == id }
        expect(diagnostic.severity).to eq(:warning), id
      end
    end

    it "keeps a payload overrun an error under the tolerant profile" do
      errors = Emf::Conformance.check(cases.fetch("emf.escape.payload_bounds").first, profile: :tolerant).errors.map(&:requirement_id)
      expect(errors).to include("emf.escape.payload_bounds")
    end
  end
end
