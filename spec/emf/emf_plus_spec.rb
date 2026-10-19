# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_records"

RSpec.describe Emf::EmfPlus do
  include Emf::SpecSupport::EmfPlusRecords

  let(:header) { record(0x4001, [1, 0x1234, 96, 96].pack("V4"), flags: 1) }
  let(:unknown) { record(0x7FFF, "\x01\x02\x03\x04".b, flags: 0x55AA) }
  let(:stream) { header + unknown }

  describe Emf::EmfPlus::Parser do
    it "frames a known record and an unknown type without dropping either" do
      frames = described_class.call(stream)

      expect(frames.map(&:type)).to eq([0x4001, 0x7FFF])
      expect(frames.map(&:offset)).to eq([0, header.bytesize])
      expect(frames.last).to have_attributes(flags: 0x55AA, size: 16, data_size: 4, data: "\x01\x02\x03\x04".b)
    end

    it "frames an empty stream as no records" do
      expect(described_class.call("")).to eq([])
    end

    it "keeps body bytes beyond DataSize so padded records round-trip" do
      padded = record(0x4002, "abcdefgh", data_size: 3)
      frame = described_class.call(padded).first

      expect(frame).to have_attributes(data_size: 3, data: "abcdefgh".b)
    end

    {
      "Size below the 12-byte header" => ->(s) { s.record(1, "", size: 8) },
      "Size not a multiple of 4" => ->(s) { s.record(1, "abcde") },
      "DataSize larger than Size - 12" => ->(s) { s.record(1, "abcd", data_size: 8) },
      "record running past the end" => ->(s) { s.record(1, "abcd", size: 32) },
      "truncated header" => ->(_s) { "\x01\x40\x00".b }
    }.each do |label, build|
      it "raises ParseError for #{label}" do
        expect { described_class.call(build.call(self)) }.to raise_error(Emf::ParseError, /offset 0/)
      end
    end

    it "reports the offset and type of the malformed record" do
      bad = stream + record(0x4009, "abcd", size: 40)

      expect { described_class.call(bad) }
        .to raise_error(Emf::ParseError) { |e| expect([e.offset, e.record_code]).to eq([stream.bytesize, 0x4009]) }
    end

    it "collects the error and returns the frames read so far when given errors:" do
      errors = []
      frames = described_class.call(stream + "\x01\x02\x03".b, errors: errors)

      expect(frames.map(&:type)).to eq([0x4001, 0x7FFF])
      expect(errors.map(&:offset)).to eq([stream.bytesize])
    end
  end

  describe Emf::EmfPlus::Serializer do
    it "reproduces unedited frames byte for byte" do
      padded = record(0x4002, "abcdefgh", data_size: 3)
      bytes = stream + padded

      expect(described_class.call(Emf::EmfPlus::Parser.call(bytes))).to eq(bytes.b)
    end

    it "recomputes Size and DataSize for an edited frame" do
      frames = Emf::EmfPlus::Parser.call(stream)
      new_data = "\x01\x02\x03\x04\x05\x06\x07\x08".b
      edited = frames.last.with_data(new_data)

      expect(described_class.call([frames.first, edited])).to eq(header + record(0x7FFF, new_data, flags: 0x55AA))
    end

    it "pads an unaligned edit to a 4-byte Size that re-parses, keeping the real DataSize" do
      edited = Emf::EmfPlus::Parser.call(unknown).first.with_data("abcde".b)
      reparsed = Emf::EmfPlus::Parser.call(described_class.call([edited])).first

      expect(reparsed).to have_attributes(size: 20, data_size: 5, data: "abcde\0\0\0".b)
    end
  end

  describe "against real corpus files" do
    %w[EA-test-file-020 EA-test-file-101 EA-test-file-102].each do |name|
      context name do
        let(:metafile) { Emf.parse(File.binread(File.expand_path("../fixtures/emf-ea/#{name}.emf", __dir__))) }
        let(:frames) { Emf::EmfPlus::Parser.from_metafile(metafile) }

        it "contains EMF+" do
          expect(metafile.emf_plus).not_to be_nil
        end

        it "concatenated comment segmentation equals Metafile#emf_plus" do
          payloads = Emf::EmfPlus::Serializer.by_comment(frames).sort.map(&:last)

          expect(payloads.join.b).to eq(metafile.emf_plus.b)
        end

        it "frames the concatenated stream and re-serializes it identically" do
          expect(Emf::EmfPlus::Serializer.call(Emf::EmfPlus::Parser.call(metafile.emf_plus))).to eq(metafile.emf_plus.b)
        end

        it "tags each frame with its source comment and keeps frames within comments" do
          comment_indexes = metafile.records.each_index.select { |i| metafile.records[i].wire.is_a?(Emf::Emr::Binary::Records::Comment) }

          expect(frames.map(&:comment_index).uniq - comment_indexes).to be_empty
          expect(frames.map(&:comment_index)).to eq(frames.map(&:comment_index).sort)
        end

        it "round-trips each comment's payload against the original comment bytes" do
          by_comment = Emf::EmfPlus::Serializer.by_comment(frames)

          by_comment.each do |index, payload|
            expect(payload).to eq(Emf::Emr::Parser.extract_emf_plus(metafile.records[index].wire).b)
          end
        end
      end
    end
  end
end
