# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"

RSpec.describe "variable buffers on the public model" do
  include_context "with native library"

  r = Emf::Emr::Binary::Records
  families = {
    bitmap: [r::BitBlt, r::StretchBlt, r::StretchDIBits, r::SetDibitsToDevice, r::AlphaBlend, r::TransparentBlt,
             r::MaskBlt, r::PlgBlt, r::CreateDibPatternBrushPt, r::CreateMonoBrush, r::ExtCreatePen],
    region: [r::FillRgn, r::FrameRgn, r::InvertRgn, r::PaintRgn, r::ExtSelectClipRgn],
    gradient: [r::GradientFill],
    profile: [r::SetIcmProfileA, r::SetIcmProfileW],
    palette: [r::ColorCorrectPalette]
  }

  def parse_with(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    Emf.parse(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def buffer_names(klass)
    klass.buffer_specs.keys
  end

  def observe(metafile)
    metafile.records.filter_map do |record|
      wire = record.respond_to?(:wire) ? record.wire : nil
      next unless wire.class.include?(Emf::Emr::Binary::VariableBuffers)

      [wire.class.name, record.suffix, wire.layout_surplus_bytes, buffer_names(wire.class).to_h { |n| [n, wire.public_send(n)] }]
    end
  end

  def fixtures
    %w[emf emf-ea emf-corrupted].flat_map { |dir| Dir[File.join("spec/fixtures", dir, "*.emf")] }.sort
  end

  it "is identical on the Ruby and native backends, with counts per family" do
    counts = Hash.new(0)
    mismatches = fixtures.filter_map do |path|
      bytes = File.binread(path)
      ruby = observe(parse_with("ruby", bytes))
      native = observe(parse_with("native", bytes))
      ruby.each do |name, suffix, surplus, buffers|
        family = families.find { |_, klasses| klasses.map(&:name).include?(name) }.first
        counts[:"#{family}_records"] += 1
        counts[:"#{family}_buffers"] += buffers.values.count { |v| !v.nil? && !v.respond_to?(:key?) }
        counts[:"#{family}_surplus"] += 1 if surplus && !surplus.empty?
        counts[:absorbed_with_empty_suffix] += 1 if suffix.empty? && buffers.values.any?
      end
      path unless ruby == native
    rescue Emf::Error
      nil
    end
    puts "variable buffer counts: #{counts.sort.to_h}"
    expect(mismatches).to eq([])
    expect(counts[:bitmap_buffers]).to be_positive
    expect(counts[:region_buffers]).to be_positive
    expect(counts[:absorbed_with_empty_suffix]).to be_positive
  end

  describe "synthetic records" do
    let(:extra) { "\xAA".b * 8 }

    it "returns bmi, bits and the surplus of a bitmap record" do
      body = ("B".b * 8) + ("P".b * 4) + extra
      rec = r::BitBlt.new(i_type: 76, n_size: 100 + body.bytesize, off_bmi_src: 100, cb_bmi_src: 8,
                          off_bits_src: 108, cb_bits_src: 4, body: body)
      expect([rec.bmi_bytes, rec.bits_bytes, rec.layout_surplus_bytes]).to eq(["B".b * 8, "P".b * 4, extra])
    end

    it "returns nil for parts that are absent, in the fixed layout or past the record" do
      rec = r::BitBlt.new(i_type: 76, n_size: 108, off_bmi_src: 50, cb_bmi_src: 8,
                          off_bits_src: 0xFFFFFFF0, cb_bits_src: 0xFFFFFFF0, body: "x".b * 8)
      expect([rec.bmi_bytes, rec.bits_bytes]).to eq([nil, nil])
      expect(rec.layout_surplus_bytes).to eq("x".b * 8)
    end

    it "returns nil surplus when nSize is under the layout or over the record" do
      under = r::BitBlt.new(i_type: 76, n_size: 60, body: "".b)
      over = r::BitBlt.new(i_type: 76, n_size: 400, body: "".b)
      expect([under.layout_surplus_bytes, over.layout_surplus_bytes]).to eq([nil, nil])
    end

    it "returns region bytes and surplus when the region is followed by extra bytes" do
      region = [32, 1, 0, 0, 0, 0, 0, 0, 0, 0].pack("V*") + ("\0".b * 12)
      rec = r::FillRgn.new(i_type: 43, n_size: 32 + region.bytesize + 8, cb_rgn_data: region.bytesize,
                           rgn_data: r::FillRgn.new.rgn_data.class.new(byte_length: region.bytesize).read(region), body: extra)
      expect(rec.region_bytes).to eq(region.b)
      expect(rec.layout_surplus_bytes).to eq(extra)
    end

    it "reports a region that overruns the record as nil" do
      rec = r::InvertRgn.new(i_type: 46, n_size: 28, cb_rgn_data: 0xFFFFFFFF)
      expect([rec.region_bytes, rec.layout_surplus_bytes]).to eq([nil, "".b])
    end

    it "returns gradient vertices and mesh" do
      verts = "V".b * 32
      mesh = [0, 1, 1, 0].pack("V*") # not used: mode 0 is a rect pair per index
      rec = r::GradientFill.new(i_type: 118, n_size: 36 + 32 + 8 + extra.bytesize, n_ver: 2, n_tri: 1, ul_mode: 0,
                                body: verts + mesh.byteslice(0, 8) + extra)
      expect([rec.vertex_bytes, rec.mesh_bytes.bytesize, rec.layout_surplus_bytes]).to eq([verts, 8, extra])
    end

    it "finds the surplus after the name and profile of an ICM profile" do
      rec = r::SetIcmProfileA.new(i_type: 112, n_size: 20 + 3 + 2 + 8,
                                  body: [0, 3, 2].pack("V*") + "abcde".b + extra)
      expect([rec.icm_name_bytes, rec.icm_profile_bytes, rec.layout_surplus_bytes]).to eq(["abc", "de", extra])
    end

    it "finds the surplus after a ColorCorrectPalette's fixed fields" do
      rec = r::ColorCorrectPalette.new(i_type: 111, n_size: 32, body: ("\0".b * 16) + extra)
      expect(rec.layout_surplus_bytes).to eq(extra)
    end
  end
end
