# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"

RSpec.describe "conformance model fields" do
  include_context "with native library"

  def parse_with(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    Emf.parse(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def observe(metafile)
    header = metafile.header
    records = metafile.records.filter_map do |record|
      wire = record.respond_to?(:wire) ? record.wire : nil
      case wire
      when Emf::Emr::Binary::Records::Eof then [:eof, record.offset, wire.n_pal_entries, wire.off_pal_entries, wire.palette_bytes]
      when Emf::Emr::Binary::Records::ExtTextOutA, Emf::Emr::Binary::Records::ExtTextOutW
        [wire.class.name, wire.string_bytes, wire.text, wire.dx]
      end
    end
    stream = metafile.emf_plus_stream
    offsets = stream&.each_record&.map(&:comment_offset)
    { header: [header.description, header.description_bytes, header.pixel_format_bytes], records: records, offsets: offsets }
  end

  def fixtures
    %w[emf emf-ea emf-corrupted].flat_map { |dir| Dir[File.join("spec/fixtures", dir, "*.emf")] }.sort
  end

  it "is identical on the Ruby and native backends" do
    counts = Hash.new(0)
    mismatches = fixtures.filter_map do |path|
      bytes = File.binread(path)
      ruby = observe(parse_with("ruby", bytes))
      native = observe(parse_with("native", bytes))
      counts[:fixtures] += 1
      counts[:description] += 1 if ruby[:header][0]
      counts[:palette] += ruby[:records].count { |r| r[0] == :eof && r[4] }
      counts[:text] += ruby[:records].count { |r| r[0] != :eof }
      counts[:comment_offsets] += ruby[:offsets].to_a.compact.size
      path unless ruby == native
    rescue Emf::Error
      nil
    end
    expect(mismatches).to eq([])
    expect(counts.values_at(:fixtures, :description, :text, :comment_offsets).all?(&:positive?)).to be(true), counts.inspect
  end

  it "gives each EMF+ record the file offset of its EMR_COMMENT" do
    path = Dir["spec/fixtures/emf-ea/*.emf"].min_by { |p| parse_with("ruby", File.binread(p)).format == :emf_plus ? 0 : 1 }
    metafile = parse_with("ruby", File.binread(path))
    comments = metafile.records.select { |r| r.wire.is_a?(Emf::Emr::Binary::Records::Comment) }.map(&:offset)
    offsets = metafile.emf_plus_stream.each_record.map(&:comment_offset)
    expect(offsets).not_to be_empty
    expect(offsets.uniq - comments).to eq([])
  end

  describe "malformed input" do
    it "returns nil for header ranges outside the record and reads in-range ones" do
      wire = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, n_description: 0xFFFFFFFF, off_description: 0xFFFFFFF0,
                                          cb_pixel_format: 0xFFFFFFFF, off_pixel_format: 4)
      bad = Emf::Model::Emr::Header.from_wire(wire)
      ok_wire = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 124, n_description: 2, off_description: 108,
                                             cb_pixel_format: 4, off_pixel_format: 112, trailing: "h\0i\0".b + "PFD!".b)
      ok = Emf::Model::Emr::Header.from_wire(ok_wire)
      expect([bad.description, bad.description_bytes, bad.pixel_format_bytes]).to eq([nil, nil, nil])
      expect([ok.description, ok.pixel_format_bytes]).to eq(["hi", "PFD!"])
    end

    it "reads the header buffers from the current trailing bytes, also after an edit" do
      wire = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 124, n_description: 2, off_description: 108,
                                          cb_pixel_format: 4, off_pixel_format: 112, trailing: "h\0i\0".b + "ABCD".b)
      header = Emf::Model::Emr::Header.from_wire(wire)
      expect(header.pixel_format_bytes).to eq("ABCD")
      header.trailing.replace("h\0i\0".b + "WXYZ".b)
      expect([header.pixel_format_bytes, header.record_bytes.byteslice(112, 4)]).to eq(%w[WXYZ WXYZ])
    end

    it "returns nil for text, Dx and palette ranges outside the record" do
      text = Emf::Emr::Binary::Records::ExtTextOutW.new(i_type: 84, n_size: 76, n_chars: 0xFFFFFFFF,
                                                        off_string: 0xFFFFFFFF, off_dx: 0xFFFFFFF0)
      eof = Emf::Emr::Binary::Records::Eof.new(i_type: 14, n_size: 20, n_pal_entries: 0xFFFFFFFF, off_pal_entries: 16)
      expect([text.string_bytes, text.text, text.dx, eof.palette_bytes]).to eq([nil, nil, nil, nil])
    end

    it "decodes A as Windows-1252 and W as UTF-16LE" do
      string = "h\xE9llo".b
      a = Emf::Emr::Binary::Records::ExtTextOutA.new(i_type: 83, n_chars: 5, off_string: 76, off_dx: 0, trailing: string)
      w = Emf::Emr::Binary::Records::ExtTextOutW.new(i_type: 84, n_chars: 2, off_string: 76, off_dx: 80,
                                                     trailing: "h\0i\0".b + [3, 4].pack("V2"))
      expect([a.text, w.text, w.dx]).to eq(["héllo", "hi", [3, 4]])
    end
  end
end
