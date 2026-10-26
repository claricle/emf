# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# MS-EMFPLUS 2.2.3 effect parameter ranges and 2.2.2.2/2.2.2.3 bitmap pixel data.
RSpec.describe "EMF+ effect parameters and bitmap pixel data" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:effect_id) { "emfplus.object.effect_parameters" }
  let(:pixel_id) { "emfplus.image.pixel_data" }
  let(:argb) { 0x0026200A } # PixelFormat32bppARGB, 32 bits per pixel

  guids = {
    blur: "633c80a4-1843-482b-9ef2-be2834c5fdd4", brightness_contrast: "d3a1dbe1-8ec4-4c17-9f4c-ea97ad1c343d",
    color_balance: "537e597d-251e-48da-9664-29ca496b70f8", color_curve: "dd6a0022-58e4-4a67-9d9b-d48eb881a53d",
    color_matrix: "718f2615-7933-40e3-a511-5f68fe14dd74", hsl: "8b2dd6c3-eb07-4d87-a5f0-7108e26a9c5f",
    levels: "99c354ec-2a31-4f3a-8c34-17a803b33a25", sharpen: "63cbf3ee-c526-402c-8f71-62c540bf5142",
    tint: "1077af00-2848-4441-9489-44ad4c2d7a2c"
  }.freeze
  define_method(:guids) { guids }

  def guid_bytes(text)
    a, b, c, d, e = text.split("-")
    [a, b, c].map { |part| [part].pack("H*").reverse }.join + [d, e].pack("H*H*")
  end

  def effect_stream(kind, buffer)
    body = guid_bytes(guids.fetch(kind)) + [buffer.bytesize].pack("V") + buffer
    build.stream(build.record(0x4038, body: body))
  end

  def effect_findings(kind, buffer, profile: :strict)
    build.diagnostics(effect_stream(kind, buffer), effect_id, profile: profile)
  end

  def bitmap_stream(width:, height:, stride:, pixels:, format: argb)
    bitmap = [width, height, stride, format, 0].pack("l<l<l<VV") + pixels
    image = [0xDBC01002, 1].pack("V2") + bitmap
    build.stream(build.object(5, 0, image))
  end

  def pixel_findings(**args) = build.diagnostics(bitmap_stream(**args), pixel_id)

  it "rejects the Codex Blur reproducer (BlurRadius 999.0) in strict" do
    findings = effect_findings(:blur, [999.0].pack("e") + [0].pack("V"))
    expect(findings.map(&:message).join).to include("BlurRadius 999.0 is outside 0.0..255.0")
  end

  it "accepts BlurRadius at both ends of its range and an ExpandEdge of 1" do
    expect(effect_findings(:blur, [0.0].pack("e") + [1].pack("V"))).to be_empty
    expect(effect_findings(:blur, [255.0].pack("e") + [1].pack("V"))).to be_empty
  end

  it "rejects a NaN BlurRadius and an ExpandEdge of 2" do
    expect(effect_findings(:blur, [Float::NAN].pack("e") + [0].pack("V"))).not_to be_empty
    expect(effect_findings(:blur, [1.0].pack("e") + [2].pack("V"))).not_to be_empty
  end

  {
    brightness_contrast: [[[255, 100], [-255, -100]], [[256, 0], [0, 101], [0, -101]], "l<2"],
    color_balance: [[[100, -100, 0]], [[101, 0, 0], [0, -101, 0], [0, 0, 101]], "l<3"],
    hsl: [[[180, -100, 100], [-180, 0, -100]], [[181, 0, 0], [0, 101, 0], [0, 0, -101]], "l<3"],
    levels: [[[100, 0, 0], [0, -100, 100]], [[101, 0, 0], [-1, 0, 0], [0, 101, 0], [0, 0, -1]], "l<3"],
    tint: [[[180, 100], [-180, -100]], [[181, 0], [0, 101]], "l<2"],
    color_curve: [[[0, 0, 5], [7, 3, 255]], [[8, 0, 0], [0, 4, 0]], "Vl<2"]
  }.each do |kind, (valid, invalid, _)|
    describe "#{kind} effect" do
      def pack(kind, values) = kind == :color_curve ? [values[0], values[1], values[2]].pack("VVl<") : values.pack("l<*")

      it "accepts values inside the stated ranges" do
        valid.each { |values| expect(effect_findings(kind, pack(kind, values))).to be_empty }
      end

      it "rejects each out-of-range value" do
        invalid.each { |values| expect(effect_findings(kind, pack(kind, values))).not_to be_empty }
      end
    end
  end

  it "rejects a SharpenEffect Amount above 100 and accepts 0 and 100" do
    expect(effect_findings(:sharpen, [3.0, 100.5].pack("e2"))).not_to be_empty
    expect(effect_findings(:sharpen, [3.0, 0.0].pack("e2"))).to be_empty
    expect(effect_findings(:sharpen, [3.0, 100.0].pack("e2"))).to be_empty
  end

  it "requires Matrix[4][0..3] to be 0.0 and leaves translation column and Matrix[4][4] alone" do
    identity = Array.new(25) { |i| (i / 5) == (i % 5) ? 1.0 : 0.0 }
    expect(effect_findings(:color_matrix, identity.pack("e25"))).to be_empty
    bad = identity.dup.tap { |values| values[(2 * 5) + 4] = 0.5 } # column 2, row 4 = Matrix[4][2]
    expect(effect_findings(:color_matrix, bad.pack("e25")).map(&:message).join).to include("Matrix[4][2]")
    translated = identity.dup.tap { |values| values[(4 * 5) + 1] = 0.5 } # Matrix[1][4]
    expect(effect_findings(:color_matrix, translated.pack("e25"))).to be_empty
  end

  describe "bitmap pixel data" do
    it "rejects the Codex reproducer: 2x2, Stride 8, 4 PixelData bytes" do
      findings = pixel_findings(width: 2, height: 2, stride: 8, pixels: "\0".b * 4)
      expect(findings.map(&:message).join).to include("PixelData holds 4 bytes", "Stride 8 * Height 2 needs 16")
    end

    it "rejects a Stride smaller than a scan-line" do
      findings = pixel_findings(width: 4, height: 1, stride: 8, pixels: "\0".b * 8)
      expect(findings.map(&:message).join).to include("Stride 8 is smaller than the 16 bytes")
    end

    it "accepts a complete bitmap and one with trailing padding" do
      expect(pixel_findings(width: 2, height: 2, stride: 8, pixels: "\0".b * 16)).to be_empty
      expect(pixel_findings(width: 2, height: 2, stride: 8, pixels: "\0".b * 20)).to be_empty
    end

    it "accepts a padded 24-bit stride" do
      format = 0x00021808 # PixelFormat24bppRGB
      expect(pixel_findings(width: 3, height: 2, stride: 12, pixels: "\0".b * 24, format: format)).to be_empty
    end
  end

  it "reports the Blur reproducer in strict and in tolerant (no real file needs a waiver)" do
    bytes = effect_stream(:blur, [999.0].pack("e") + [0].pack("V"))
    %i[strict tolerant].each do |profile|
      expect(build.diagnostics(bytes, effect_id, profile: profile).map(&:severity)).to eq([:error])
    end
  end
end
