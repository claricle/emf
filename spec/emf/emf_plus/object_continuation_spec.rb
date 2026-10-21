# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EmfPlusObject continuation edge cases" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:plus) { Emf::EmfPlus }
  let(:image) { plus::Objects::IMAGE }
  let(:base) { Emf.parse(File.binread(File.join(__dir__, "../../fixtures/emf/test-000.emf"))) }

  def object(id, data, total: nil, continued: !total.nil?)
    flags = (image << 8) | id | (continued ? 0x8000 : 0)
    record(0x4008, (total ? [total].pack("V") : "".b) + data, flags: flags)
  end

  def decode(*parts) = plus::Records.decode_all(plus::Parser.call(parts.join.b))

  def comment_wire(payload)
    data = "EMF+".b + payload
    pad = -data.bytesize % 4
    Emf::Emr::Binary::Records::Comment.new(i_type: 70, n_size: 12 + data.bytesize + pad,
                                           cb_data: data.bytesize, data: data + ("\0" * pad))
  end

  def metafile_with(*payloads)
    adapters = payloads.map { |payload| Emf::Model::Emr::Records::WireAdapter.new(wire: comment_wire(payload)) }
    Emf::Model::Metafile.new(format: :emf_plus, header: base.header, records: adapters + base.records.last(1),
                             emf_plus: payloads.join, trailing: base.trailing)
  end

  def reparse(*payloads)
    bytes = Emf.serialize(metafile_with(*payloads))
    [Emf.parse(bytes), bytes]
  end

  %w[test-109 test-155].each do |name|
    context "with corpus #{name}" do
      let(:bytes) { File.binread(File.join(__dir__, "../../fixtures/emf/#{name}.emf")) }
      let(:metafile) { Emf.parse(bytes) }
      let(:records) { plus::Records.decode_all(plus::Parser.from_metafile(metafile)) }
      let(:chunks) { records.select { |r| r.is_a?(plus::Records::Object) && r.continued? } }

      it "leaves C set on the final chunk and ends the chain by TotalObjectSize" do
        expect(chunks.size).to be > 1
        expect(chunks.map(&:flags).uniq).to eq([0x8500 | chunks.first.emf_object_id])
        expect(chunks.map(&:total_object_size).uniq.size).to eq(1)
        expect(chunks.sum { |c| c.object_data.bytesize }).to eq(chunks.first.total_object_size)
      end

      it "reassembles one logical object and round-trips byte for byte" do
        logical = plus::ObjectChain.call(records).grep(plus::ObjectChain::LogicalObject).find { |o| o.chunk_sizes.size > 1 }

        expect(logical.total_size).to eq(chunks.first.total_object_size)
        expect(logical.split.map(&:to_binary)).to eq(chunks.map(&:to_binary))
        expect(metafile.emf_plus_stream.errors).to be_empty
        expect(Emf.serialize(metafile.emf_plus_stream.to_metafile)).to eq(bytes)
      end
    end
  end

  # ch02 says C is clear on the final chunk, but no corpus file does that.
  # Ruby parses that chunk without a TotalObjectSize word. LibreOffice
  # (emfphelperdata.cxx:1584) treats any chunk with the same object id as a
  # continuation and would strip its first 4 bytes as TotalObjectSize.
  context "with a final chunk whose C flag is clear" do
    let(:parts) { [object(5, "abcd", total: 8), object(5, "efgh", continued: false)] }
    let(:logical) { plus::ObjectChain.call(decode(*parts)).first }

    it "ends the chain there and keeps all of its bytes as object data" do
      expect(logical.data).to eq("abcdefgh")
      expect(logical.chunk_sizes).to eq([4, 4])
    end

    it "returns the source records unchanged" do
      expect(logical.split.map(&:to_binary)).to eq(parts)
    end

    it "round-trips through the stream without diagnostics" do
      source, bytes = reparse(*parts)

      expect(source.emf_plus_stream.errors).to be_empty
      expect(Emf.serialize(source.emf_plus_stream.to_metafile)).to eq(bytes)
    end
  end

  # LibreOffice (:1605-1614) decodes whatever it has when the next record is
  # not a matching chunk and never compares against TotalObjectSize; Ruby
  # refuses to build the logical object.
  # Chunks are [data, total]; a nil total is a C-clear chunk.
  {
    "a short chain cut by another record" =>
      [[["abcd", 12], ["efgh", 12]], "not completed by a matching chunk"],
    "a chain cut after its first chunk" => [[["abcd", 12]], "not completed by a matching chunk"],
    "a total mismatch" => [[["abcd", 6], ["efgh", 6]], "chain holds 8 bytes, TotalObjectSize is 6"],
    "a short chain closed by a C-clear chunk" =>
      [[["abcd", 12], ["efgh", nil]], "chain holds 8 bytes, TotalObjectSize is 12"]
  }.each do |label, (chunks, message)|
    context "with #{label}" do
      let(:other) { object(7, "pen!", continued: false) }
      let(:parts) { chunks.map { |data, total| object(5, data, total: total) } + [other] }

      it "raises ParseError from ObjectChain" do
        expect { plus::ObjectChain.call(decode(*parts)) }
          .to raise_error(Emf::ParseError, /#{Regexp.escape(message)}/)
      end

      it "reports an incomplete_chain diagnostic with the chunks and places nothing" do
        records = decode(*parts)
        table = plus::ObjectTable.new(records)

        expect(table.errors.map(&:kind)).to eq([:incomplete_chain])
        expect(table.errors.first.records.map(&:to_binary)).to eq(parts.first(chunks.size))
        expect(table.lookup(5, at: records.size)).to be_nil
        expect(table.lookup(7, at: records.size).data).to eq("pen!")
      end

      it "surfaces in Stream#errors only, keeping every byte and Metafile#errors unchanged" do
        source, bytes = reparse(*parts)
        stream = source.emf_plus_stream

        expect(source.errors).to eq(base.errors)
        expect(stream.errors.map(&:message)).to include(/#{Regexp.escape(message)}/)
        expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
        expect(stream.records.map { |h| h.record.to_binary }).to eq(parts)
      end
    end
  end
end
