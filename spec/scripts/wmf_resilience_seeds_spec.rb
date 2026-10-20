# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require "spec_helper"
require_relative "../../script/support/wmf_resilience_seeds"

RSpec.describe WmfResilienceSeeds do
  let(:seeds) { described_class.build }

  it "builds eight valid binary seeds across each family and container" do
    valid = seeds.select { |seed| seed.fetch("expected_outcome") == "parsed" }

    expect(valid.length).to eq(8)
    expect(valid.map { |seed| [seed.fetch("family"), seed.fetch("placeable")] }).to match_array(
      %w[geometry text bitmap unknown].product([false, true])
    )
    expect(valid).to all(include("bytes" => be_a(String), "recipe" => be_a(String)))
    expect(valid.map { |seed| seed.fetch("bytes").encoding }).to all(eq(Encoding::ASCII_8BIT))
  end

  it "round-trips every valid seed through the Ruby WMF parser" do
    seeds.select { |seed| seed.fetch("expected_outcome") == "parsed" }.each do |seed|
      metafile = Emf::Wmf::Parser.call(seed.fetch("bytes"))

      expect(metafile.format).to eq(:wmf), seed.fetch("name")
      expect(Emf::Wmf::Serializer.call(metafile)).to eq(seed.fetch("bytes")), seed.fetch("name")
    end
  end

  it "builds the eight named malformed seeds that the Ruby parser rejects" do
    malformed = seeds.select { |seed| seed.fetch("expected_outcome") == "rejected" }

    expect(malformed.map { |seed| seed.fetch("name") }).to match_array(
      %w[header-size file-size max-record zero-record missing-eof negative-text-count placeable-checksum
         bitmap-short-record]
    )
    expected_errors = {
      "header-size" => [Emf::FormatError, /HeaderSize/],
      "file-size" => [Emf::FormatError, /file Size/],
      "max-record" => [Emf::FormatError, /MaxRecord/],
      "zero-record" => [Emf::ParseError, /invalid record length/],
      "missing-eof" => [Emf::ParseError, /missing EOF/],
      "negative-text-count" => [Emf::ParseError, /negative text length/],
      "placeable-checksum" => [Emf::FormatError, /checksum mismatch/],
      "bitmap-short-record" => [Emf::ParseError, /truncated bitmap transfer prefix/]
    }
    malformed.each do |seed|
      error_class, message = expected_errors.fetch(seed.fetch("name"))
      expect { Emf::Wmf::Parser.call(seed.fetch("bytes")) }.to raise_error(error_class, message)
    end
  end

  it "returns fresh deterministic seeds with string keys and binary bytes" do
    first = described_class.build
    second = described_class.build

    expect(first.map { |seed| seed.except("bytes") }).to eq(second.map { |seed| seed.except("bytes") })
    expect(first.map { |seed| Digest::SHA256.hexdigest(seed.fetch("bytes")) }).to eq(
      second.map { |seed| Digest::SHA256.hexdigest(seed.fetch("bytes")) }
    )
    expect(first).to all(satisfy { |seed| seed.keys.all?(String) })
    expect(first).to all(satisfy { |seed| seed.fetch("bytes").encoding == Encoding::ASCII_8BIT })
    first.first.fetch("bytes").replace("changed".b)
    expect(second.first.fetch("bytes")).not_to eq("changed".b)
  end

  it "writes a deterministic manifest with hashes, sizes, paths, and synthetic provenance" do
    Dir.mktmpdir do |first_dir|
      Dir.mktmpdir do |second_dir|
        first = described_class.write(output_dir: first_dir)
        second = described_class.write(output_dir: second_dir)

        expect(first).to eq(second)
        expect(first.fetch("schema_version")).to eq(1)
        expect(first.fetch("seeds").length).to eq(16)
        expect(first.fetch("seeds")).to all(include("provenance" => "synthetic"))
        first.fetch("seeds").each do |entry|
          path = File.join(first_dir, entry.fetch("path"))
          bytes = File.binread(path)
          expect(File.file?(path)).to be(true)
          expect(entry.fetch("path")).not_to include("..")
          expect(entry).not_to have_key("bytes")
          expect(entry.fetch("sha256")).to eq(Digest::SHA256.hexdigest(bytes))
          expect(entry.fetch("size_bytes")).to eq(bytes.bytesize)
          expect(File.binread(File.join(second_dir, entry.fetch("path")))).to eq(bytes)
        end
        expect(JSON.parse(File.read(File.join(first_dir, "seeds-manifest.json")))).to eq(
          "schema_version" => 1, "seeds" => first.fetch("seeds")
        )
      end
    end
  end

  it "runs the command-line writer and reports the absolute manifest path" do
    script = File.expand_path("../../script/wmf_resilience_seeds", __dir__)
    Dir.mktmpdir do |output_dir|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--output-dir", output_dir)

      expect(status).to be_success, stderr
      expect(stdout.strip).to eq(File.join(File.expand_path(output_dir), "seeds-manifest.json"))
      expect(JSON.parse(File.read(stdout.strip)).fetch("seeds").length).to eq(16)
    end
  end
end
