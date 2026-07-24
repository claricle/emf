# frozen_string_literal: true

require "spec_helper"

# TODO.impl/16: walk every non-corrupted fixture and assert byte-identical
# round-trip (parse -> serialize -> parse produces the same file).
RSpec.describe "EMF round-trip" do
  def assert_byte_identical(path)
    bytes = File.read(path, mode: "rb")
    mf = Emf.parse(bytes)
    reborn = Emf.serialize(mf)
    expect(reborn).to eq(bytes), <<~MSG
      Round-trip drift for #{File.basename(path)}
        original: #{bytes.bytesize} bytes
        reborn:   #{reborn.bytesize} bytes
        diff:     #{(0...[bytes.bytesize, reborn.bytesize].min).find { |i| bytes.getbyte(i) != reborn.getbyte(i) } || 'end-of-shorter'}
    MSG
  end

  describe "spec/fixtures/emf/ (186 fixtures)" do
    Dir.glob(Emf::SpecSupport::FixturePath.fixture("emf", "*.emf")).each do |path|
      it "round-trips #{File.basename(path)}" do
        assert_byte_identical(path)
      end
    end
  end

  describe "spec/fixtures/emf-ea/ (21 fixtures)" do
    Dir.glob(Emf::SpecSupport::FixturePath.fixture("emf-ea", "*.emf")).each do |path|
      it "round-trips #{File.basename(path)}" do
        assert_byte_identical(path)
      end
    end
  end

  describe "spec/fixtures/simple/" do
    it "round-trips image1.emf byte-identically" do
      assert_byte_identical(Emf::SpecSupport::FixturePath.fixture("simple", "image1.emf"))
    end
  end
end
