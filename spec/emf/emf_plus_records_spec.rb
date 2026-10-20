# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Records do
  include Emf::SpecSupport::EmfPlusRecords

  def decode(bytes)
    Emf::EmfPlus::Records.decode(Emf::EmfPlus::Parser.call(bytes).first)
  end

  describe ".decode" do
    it "wraps a type without a class in Unknown and re-encodes it" do
      bytes = record(0x7FFF, "\x01\x02\x03\x04".b, flags: 0x55AA)
      unknown = decode(bytes)

      expect(unknown).to be_a(described_class::Unknown).and have_attributes(type: 0x7FFF, flags: 0x55AA)
      expect(unknown.to_binary).to eq(bytes)
    end

    it "keeps reserved types 0x4005 to 0x4007 as Unknown" do
      expect(decode(record(0x4005, "abcd"))).to be_a(described_class::Unknown)
    end

    it "decodes every frame of a stream with decode_all" do
      frames = Emf::EmfPlus::Parser.call(record(0x4004, "") + record(0x4002, ""))

      expect(described_class.decode_all(frames)).to match([be_a(described_class::GetDC), be_a(described_class::EndOfFile)])
    end
  end

  describe described_class::Header do
    let(:body) { [0xDBC01002, 0x00000001, 96, 72].pack("V4") }
    let(:bytes) { record(0x4001, body, flags: 0x0001) }
    subject(:header) { decode(bytes) }

    it "decodes version, flags and DPI" do
      expect(header).to have_attributes(graphics_signature: 0xDBC01, graphics_version: 2, logical_dpi_x: 96, logical_dpi_y: 72)
      expect(header).to be_valid_signature.and be_dual.and be_video
    end

    it "reports EMF+ Only and a non-video device" do
      only = decode(record(0x4001, [0xDBC01001, 0, 96, 96].pack("V4"), flags: 0))

      expect(only).not_to be_dual
      expect(only).not_to be_video
      expect(only.graphics_version).to eq(1)
    end

    it "keeps a wrong signature raw and flags it" do
      bad = decode(record(0x4001, [0x12345002, 0, 96, 96].pack("V4")))

      expect(bad).not_to be_valid_signature
      expect(bad.to_binary).to eq(record(0x4001, [0x12345002, 0, 96, 96].pack("V4")))
    end

    it "re-encodes identically" do
      expect(header.to_binary).to eq(bytes)
    end

    it "keeps bytes after the body so a longer record round-trips" do
      longer = record(0x4001, body + "extra!!!".b)

      expect(decode(longer).to_binary).to eq(longer)
    end

    it "raises ParseError with offset and record code for a short body" do
      expect { decode(record(0x4001, body.byteslice(0, 8))) }
        .to raise_error(Emf::ParseError, /malformed Header body/) { |e| expect([e.offset, e.record_code]).to eq([0, 0x4001]) }
    end
  end

  describe "bodiless control records" do
    {
      described_class::EndOfFile => 0x4002,
      described_class::GetDC => 0x4004
    }.each do |klass, type|
      it "decodes #{klass.name.split('::').last} and re-encodes identically" do
        bytes = record(type, "")

        expect(decode(bytes)).to be_a(klass)
        expect(decode(bytes).to_binary).to eq(bytes)
      end
    end

    it "keeps padding after an empty body" do
      bytes = record(0x4002, "\0\0\0\0".b, data_size: 0)

      expect(decode(bytes).to_binary).to eq(bytes)
    end
  end

  describe described_class::Comment do
    it "exposes the private data up to DataSize and re-encodes padding" do
      bytes = record(0x4003, "hello\0\0\0".b, data_size: 5)
      comment = decode(bytes)

      expect(comment.private_data).to eq("hello")
      expect(comment.to_binary).to eq(bytes)
    end

    it "raises ParseError when DataSize outruns the data" do
      frame = Emf::EmfPlus::Frame.new(type: 0x4003, flags: 0, size: 16, data_size: 8, data: "abcd", offset: 24)

      expect { described_class.new(frame) }
        .to raise_error(Emf::ParseError) { |e| expect([e.offset, e.record_code]).to eq([24, 0x4003]) }
    end
  end

  describe described_class::Object do
    let(:plain) { record(0x4008, "\x01\x02\x03\x04".b, flags: 0x0305) }

    it "decodes type, id and opaque data of a plain object" do
      object = decode(plain)

      expect(object).to have_attributes(object_type: 3, emf_object_id: 5, object_data: "\x01\x02\x03\x04".b, total_object_size: nil)
      expect(object).not_to be_continued
      expect(object.to_binary).to eq(plain)
    end

    it "decodes the C flag and TotalObjectSize" do
      bytes = record(0x4008, "#{[100].pack('V')}abcd", flags: 0x8500 | 7)
      object = decode(bytes)

      expect(object).to be_continued.and have_attributes(object_type: 5, emf_object_id: 7, total_object_size: 100, object_data: "abcd")
      expect(object.to_binary).to eq(bytes)
    end

    it "raises ParseError when a continued chunk has no room for TotalObjectSize" do
      expect { decode(record(0x4008, "abcd", flags: 0x8500, data_size: 2)) }.to raise_error(Emf::ParseError, /malformed Object body/)
    end
  end

  describe Emf::EmfPlus::ObjectChain do
    def chunk(data, total, flags: 0x8500)
      record(0x4008, [total].pack("V") + data, flags: flags)
    end

    def decode_all(bytes)
      Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(bytes))
    end

    let(:stream) { chunk("aaaa", 12) + chunk("bbbb", 12) + chunk("cccc", 12) + record(0x4002, "") }

    it "joins chunks into one logical object ending at TotalObjectSize" do
      entries = described_class.call(decode_all(stream))

      expect(entries.size).to eq(2)
      expect(entries.first).to have_attributes(object_type: 5, emf_object_id: 0, total_size: 12, chunk_sizes: [4, 4, 4])
      expect(entries.last).to be_a(Emf::EmfPlus::Records::EndOfFile)
    end

    it "ends the chain by size even though C stays set on the final chunk" do
      two = chunk("aaaa", 8) + chunk("bbbb", 8) + record(0x4008, "zzzz", flags: 0x0501)
      entries = described_class.call(decode_all(two))

      expect(entries.map(&:class)).to eq([described_class::LogicalObject, described_class::LogicalObject])
      expect(entries.last).to have_attributes(emf_object_id: 1, data: "zzzz")
      expect(entries.first.data).to eq("aaaabbbb")
    end

    it "splits back into chunks that re-encode to the original bytes" do
      logical = described_class.call(decode_all(stream)).first

      expect(logical.split.map(&:to_binary).join).to eq(stream.byteslice(0, stream.bytesize - 12))
    end

    it "keeps a plain object's nonzero padding when split without edits" do
      plain = record(0x4008, "a\x91\x92\x93".b, flags: 0x0102, data_size: 1)
      logical = described_class.call(decode_all(plain)).first

      expect(logical.split.map(&:to_binary).join).to eq(plain)
    end

    it "keeps each chunk's padding and source comment when a chain is split without edits" do
      padded = record(0x4008, [5].pack("V") + "aaaa\x77\x66\x55\x44".b, flags: 0x8500, data_size: 8) +
               record(0x4008, [5].pack("V") + "b\x88\x99\xAA".b, flags: 0x8500, data_size: 5)
      records = Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(padded, comment_index: 7))
      chunks = described_class.call(records).first.split

      expect(chunks.map(&:to_binary).join).to eq(padded)
      expect(chunks.map(&:comment_index)).to eq([7, 7])
      expect(chunks.map(&:offset)).to eq([0, 24])
    end

    it "re-chunks to new sizes, marking every chunk continued, and joins back to the same data" do
      logical = described_class.call(decode_all(record(0x4008, "abcdef\0\0", flags: 0x0102, data_size: 6))).first
      chunks = logical.split([4, 2])

      expect(chunks).to all(have_attributes(continued?: true, total_object_size: 6, emf_object_id: 2))
      expect(described_class.call(chunks).first).to have_attributes(data: "abcdef", chunk_sizes: [4, 2])
    end

    it "rejects split sizes that do not cover the data exactly" do
      logical = described_class.call(decode_all(stream)).first

      expect { logical.split([4, 4]) }.to raise_error(ArgumentError, /12/)
      expect { logical.split([12, 0]) }.to raise_error(ArgumentError)
      expect { logical.split([]) }.to raise_error(ArgumentError)
    end

    it "accepts the spec layout: a final chunk with C clear and no TotalObjectSize, and splits it back" do
      spec_layout = chunk("aaaa", 8) + record(0x4008, "bbbb", flags: 0x0500)
      logical = described_class.call(decode_all(spec_layout)).first

      expect(logical).to have_attributes(data: "aaaabbbb", chunk_sizes: [4, 4])
      expect(logical.split.map(&:to_binary).join).to eq(spec_layout)
    end

    it "treats a plain object as a one-chunk logical object" do
      bytes = record(0x4008, "abcd", flags: 0x0102)
      logical = described_class.call(decode_all(bytes)).first

      expect(logical).to have_attributes(object_type: 1, emf_object_id: 2, data: "abcd", total_size: 4)
      expect(logical.split.map(&:to_binary).join).to eq(bytes)
    end

    it "raises ParseError when the chain is cut off by another record" do
      bytes = chunk("aaaa", 8) + record(0x4002, "")

      expect { described_class.call(decode_all(bytes)) }
        .to raise_error(Emf::ParseError, /not completed/) { |e| expect([e.offset, e.record_code]).to eq([0, 0x4008]) }
    end

    it "raises ParseError when the chain runs out of records" do
      expect { described_class.call(decode_all(chunk("aaaa", 8))) }.to raise_error(Emf::ParseError, /not completed/)
    end

    it "raises ParseError when chunks overshoot TotalObjectSize" do
      bytes = chunk("aaaa", 6) + chunk("bbbb", 6)

      expect { described_class.call(decode_all(bytes)) }.to raise_error(Emf::ParseError, /TotalObjectSize is 6/)
    end
  end

  describe "against the corpus" do
    # The byte check skips parsing the ~185 fixtures with no EMF+ comment; parsing them all costs minutes.
    fixtures = Dir[File.expand_path("../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      bytes = File.binread(path)
      bytes.include?("EMF+") && Emf.parse(bytes).emf_plus
    rescue Emf::Error
      false
    end

    it "finds EMF+ fixtures to check" do
      expect(fixtures).not_to be_empty
    end

    fixtures.each do |path|
      context File.basename(path) do
        let(:metafile) { Emf.parse(File.binread(path)) }
        let(:records) { described_class.decode_all(Emf::EmfPlus::Parser.call(metafile.emf_plus)) }

        it "re-encodes every typed record to the original Metafile#emf_plus bytes" do
          expect(records.map(&:to_binary).join.b).to eq(metafile.emf_plus.b)
        end

        it "reassembles every object chain to TotalObjectSize bytes and splits it back identically" do
          chunks = records.grep(described_class::Object)
          logicals = Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject)

          expect(logicals.sum { |l| l.split.size }).to eq(chunks.size)
          expect(logicals.flat_map(&:split).map(&:to_binary)).to eq(chunks.map(&:to_binary))
        end
      end
    end

    { "emf/test-109.emf" => [122_108, 2], "emf/test-155.emf" => [240_420, 4] }.each do |name, (total, chunk_count)|
      it "reassembles the #{name} chain to exactly #{total} bytes in #{chunk_count} chunks" do
        metafile = Emf.parse(File.binread(File.expand_path("../fixtures/#{name}", __dir__)))
        records = described_class.decode_all(Emf::EmfPlus::Parser.call(metafile.emf_plus))
        logical = Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject).find { |l| l.chunk_sizes.size > 1 }

        expect(logical.total_size).to eq(total)
        expect(logical.chunk_sizes.size).to eq(chunk_count)
        expect(logical.data.bytesize).to eq(records.grep(described_class::Object).find(&:continued?).total_object_size)
      end
    end
  end
end
