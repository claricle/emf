# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Binary::Codec do
  describe ".utf16le_to_utf8" do
    it "decodes UTF-16LE bytes to UTF-8 string" do
      bytes = "Héllo".encode("UTF-16LE").force_encoding("BINARY")
      expect(described_class.utf16le_to_utf8(bytes)).to eq("Héllo")
    end

    it "handles ASCII passthrough" do
      bytes = "hello".encode("UTF-16LE").force_encoding("BINARY")
      expect(described_class.utf16le_to_utf8(bytes)).to eq("hello")
    end
  end

  describe ".cp1252_to_utf8" do
    it "decodes CP1252 smart quotes and ellipsis" do
      # 0x94 in CP1252 is right double quote (U+201D), 0x85 is horizontal ellipsis (U+2026).
      bytes = [0x94, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x85].pack("C*")
      expected = [0x201D, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x2026].pack("U*")
      expect(described_class.cp1252_to_utf8(bytes)).to eq(expected)
    end
  end
end
