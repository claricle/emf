# frozen_string_literal: true

require "spec_helper"
require_relative "support/text_cases"

RSpec.describe "Emf::Conformance hardening audit (objects, geometry, bitmap, comment, text)" do
  let(:text) { Emf::SpecSupport::TextCases }

  def fired(bytes)
    Emf::Conformance.check(bytes, profile: :strict).diagnostics.map(&:requirement_id).uniq
  end

  # A lone 0xDF54 code unit in the string of an EXTTEXTOUTW.
  def with_code_unit(options)
    record = text.ext(options: options)
    record[76, 2] = [0xDF54].pack("v")
    text.file(record)
  end

  describe "emf.exttextout.string_encoding" do
    it "is silent when ETO_GLYPH_INDEX makes the string glyph indexes (MS-EMF 2.1.11)" do
      expect(fired(with_code_unit(0x10))).not_to include("emf.exttextout.string_encoding")
    end

    it "still reports an unpaired surrogate in a character string" do
      expect(fired(with_code_unit(0))).to include("emf.exttextout.string_encoding")
    end
  end
end
