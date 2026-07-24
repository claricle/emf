# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Detector do
  let(:emf_bytes) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")[0, 64] }

  # 0x9AC6CDD7 + handle(2 bytes) + bbox(8 bytes) + inch(2) + reserved(4) + checksum(2)
  let(:apm_wmf_bytes) do
    [0xD7, 0xCD, 0xC6, 0x9A, 0x00, 0x00, 0, 0, 0, 0, 100, 0, 100, 0, 0x57, 0x06,
     0x00, 0x00, 0x00, 0x00, 0xAD, 0x04].pack("C*")
  end

  let(:standard_wmf_bytes) do
    # metafile_type=1 (memory), header_size=9 (words), version=0x0300, ...
    [0x01, 0x00, 0x09, 0x00, 0x00, 0x03, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0].pack("C*")
  end

  it "detects EMF from a real fixture prefix" do
    expect(described_class.call(emf_bytes)).to eq(:emf)
  end

  it "detects APM WMF by magic" do
    expect(described_class.call(apm_wmf_bytes)).to eq(:wmf_apm)
  end

  it "detects standard WMF by METAHEADER shape" do
    expect(described_class.call(standard_wmf_bytes)).to eq(:wmf_standard)
  end

  it "raises on garbage input" do
    expect { described_class.call("hello, world!".b) }.to raise_error(Emf::FormatError)
  end

  it "raises on too-short input" do
    expect { described_class.call("\x00\x00".b) }.to raise_error(Emf::FormatError)
  end
end

RSpec.describe Emf, ".detect_format" do
  it "returns :emf for an EMF fixture" do
    bytes = Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")
    expect(Emf.detect_format(bytes)).to eq(:emf)
  end
end
