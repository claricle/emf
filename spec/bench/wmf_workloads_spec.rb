# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "open3"
require "tmpdir"
require_relative "../../bench/support/wmf_workloads"

RSpec.describe ParserBenchmark::WmfWorkloads do
  let(:families) { %i[geometry text bitmap unknown] }
  let(:containers) { [false, true] }

  it "builds deterministic, structurally valid WMFs that round trip for each family and container" do
    families.each do |family|
      containers.each do |placeable|
        bytes = described_class.build(family: family, repetitions: 3, placeable: placeable)
        wmf_offset = placeable ? 22 : 0

        expect(described_class.build(family: family, repetitions: 3, placeable: placeable)).to eq(bytes)
        expect(bytes.bytesize).to be > 18
        expect(bytes.bytesize).to eq((bytes.byteslice(wmf_offset + 6, 4).unpack1("V") * 2) + wmf_offset)

        if placeable
          expect(bytes.byteslice(0, 4).unpack1("V")).to eq(0x9AC6CDD7)
          expect(bytes.byteslice(20, 2).unpack1("v")).to eq(Emf::Wmf::Binary.checksum(bytes.byteslice(0, 20)))
        else
          expect(bytes.byteslice(0, 2).unpack1("v")).to eq(2)
        end

        metafile = Emf::Wmf::Parser.call(bytes)
        expect(metafile).to be_ok
        records = metafile.records
        case family
        when :geometry
          expect(records[0]).to be_a(Emf::Model::Wmf::Records::MoveTo)
          expect([records[0].x, records[0].y]).to eq([20, -30])
          expect(records[1]).to be_a(Emf::Model::Wmf::Records::LineTo)
          expect([records[1].x, records[1].y]).to eq([-50, 40])
        when :text
          expect(records[0]).to be_a(Emf::Model::Wmf::Records::TextOut)
          expect(records[0].text).to eq("WMF text!")
          expect([records[0].x, records[0].y]).to eq([30, -20])
        when :bitmap
          expect(records[0]).to be_a(Emf::Model::Wmf::Records::DibStretchBlt)
          expect(records[0].type_id).to eq(0x0B41)
          expect([records[0].destination_width, records[0].destination_height]).to eq([1, 1])
          expect(records[0].bitmap.byteslice(0, 12).unpack("V l<2")).to eq([40, 1, 1])
        end
        offset = wmf_offset + 18
        record_lengths = []
        while offset < bytes.bytesize
          words = bytes.byteslice(offset, 4).unpack1("V")
          record_lengths << words
          offset += words * 2
        end
        expect(offset).to eq(bytes.bytesize)
        max_record_words = record_lengths.max
        expect(bytes.byteslice(wmf_offset + 12, 4).unpack1("V")).to eq(max_record_words)
        expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
      end
    end
  end

  it "scales generated record counts with repetitions" do
    families.each do |family|
      one = Emf::Wmf::Parser.call(described_class.build(family: family, repetitions: 1)).records.length - 1
      three = Emf::Wmf::Parser.call(described_class.build(family: family, repetitions: 3)).records.length - 1

      expect(three).to eq(one * 3), "#{family} should contain three times as many workload records"
    end
  end

  it "retains the complete unknown function and payload" do
    bytes = described_class.build(family: :unknown, repetitions: 2)
    unknowns = Emf::Wmf::Parser.call(bytes).records.grep(Emf::Model::Wmf::Records::UnknownRecord)

    expect(unknowns).not_to be_empty
    unknowns.each do |record|
      expect(record.type_id).to eq(0x80FE)
      expect(record.raw_bytes.byteslice(4, 2).unpack1("v")).to eq(0x80FE)
      expect(record.raw_bytes.byteslice(6..)).to eq("\x00\xFFopaque".b)
    end
  end

  describe ".write" do
    let(:tmpdir) { Dir.mktmpdir("wmf-workloads") }

    after { FileUtils.remove_entry(tmpdir) }

    it "writes eight deterministic workload files and a manifest of their actual bytes" do
      manifest = described_class.write(output_dir: tmpdir, repetitions: 2)

      expect(manifest).to include("schema_version" => 1)
      expect(manifest.fetch("workloads").length).to eq(8)
      manifest.fetch("workloads").each do |entry|
        bytes = File.binread(File.join(tmpdir, entry.fetch("path")))
        expect(entry).to include("sha256" => Digest::SHA256.hexdigest(bytes), "size_bytes" => bytes.bytesize,
                                 "repetitions" => 2, "provenance" => "synthetic")
        expect([true, false]).to include(entry.fetch("placeable"))
        expect(%w[geometry text bitmap unknown]).to include(entry.fetch("family"))
      end
      expect(JSON.parse(File.read(File.join(tmpdir, "workload-manifest.json")))).to eq(manifest)
    end
  end

  describe "CLI" do
    let(:tmpdir) { Dir.mktmpdir("wmf-workloads-cli") }
    let(:script) { File.expand_path("../../bench/wmf_workloads.rb", __dir__) }

    after { FileUtils.remove_entry(tmpdir) }

    it "prints the manifest path after writing the requested workloads" do
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--output-dir", tmpdir, "--repetitions", "2")

      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout.strip).to eq(File.join(tmpdir, "workload-manifest.json"))
      expect(JSON.parse(File.read(stdout.strip)).fetch("workloads").length).to eq(8)
    end

    %w[0 10001].each do |repetitions|
      it "rejects repetitions outside 1..10000 (#{repetitions})" do
        _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--output-dir", tmpdir, "--repetitions", repetitions)

        expect(status.exitstatus).to eq(1)
        expect(stderr).to match(/repetitions/i)
        expect(File).not_to exist(File.join(tmpdir, "workload-manifest.json"))
      end
    end
  end
end
