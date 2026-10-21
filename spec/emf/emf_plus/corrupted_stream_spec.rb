# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_generated_fixtures"

RSpec.describe Emf::EmfPlus::Stream, "corrupt input recovery" do
  fixture_cases = {
    "2014-12-07-163010" => { comments: 2033, bytes: 168_856, records: 2082, unframed: 52, errors: 1 },
    "2014-12-13-132605" => { comments: 4, bytes: 460, records: 21, unframed: 0, errors: 0 },
    "2017-02-11-230400" => { comments: 29, bytes: 2100, records: 37, unframed: 0, errors: 0 },
    "2017-02-12-010400" => { comments: 24, bytes: 28_136, records: 1137, unframed: 340, errors: 2 }
  }

  fixture_cases.each do |name, expected|
    context "with corrupted fixture #{name}" do
      let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("emf-corrupted", "bad_corrupted_#{name}.emf") }
      let(:source) { Emf.parse(bytes) }
      let(:stream) { source.emf_plus_stream }

      it "segments each actual comment and retains its complete malformed suffix" do
        expect(source.format).to eq(:emf_plus)
        expect(stream.segments.size).to eq(expected.fetch(:comments))
        expect(stream.segments.sum { |segment| segment.payload.bytesize }).to eq(expected.fetch(:bytes))
        expect(stream.records.size).to eq(expected.fetch(:records))
        expect(stream.segments.sum { |segment| segment.unframed.bytesize }).to eq(expected.fetch(:unframed))
        expect(stream.errors.size).to eq(expected.fetch(:errors))
        stream.segments.each do |segment|
          wire = source.records.fetch(segment.record_index).wire
          expect(segment.payload).to eq(wire.data.byteslice(segment.payload_range))
          expect(segment.records.map(&:to_binary).join.b + segment.unframed).to eq(segment.payload)
        end
      end

      it "preserves every original byte through the public parser and unedited stream" do
        expect(stream.to_metafile).to equal(source)
        expect(Emf.serialize(stream.to_metafile).bytesize).to eq(bytes.bytesize)
        expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
      end
    end
  end

  it "retains a short record header and resumes in the following comment" do
    fixtures = Emf::SpecSupport::EmfPlusGeneratedFixtures
    short_header = [0x4009, 0].pack("v2")
    bytes = fixtures.emf_file([fixtures.plus_header + short_header, fixtures.typed_record(:Clear) + fixtures.plus_eof])
    source = Emf.parse(bytes)
    stream = source.emf_plus_stream

    expect(source.errors).to be_empty
    expect(stream.errors.map(&:message)).to eq(["truncated EMF+ record header (4 bytes left) at offset 28"])
    expect(stream.segments.first.unframed).to eq(short_header)
    expect(stream.records.map { |handle| handle.record.type }).to eq([0x4001, 0x4009, 0x4002])
    expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
  end

  Emf::SpecSupport::EmfPlusGeneratedFixtures.malformed_frames.each do |name, malformed|
    context "with #{name} framing" do
      let(:fixtures) { Emf::SpecSupport::EmfPlusGeneratedFixtures }
      let(:bytes) { fixtures.malformed_comment_file(malformed) }
      let(:source) { Emf.parse(bytes) }
      let(:stream) { source.emf_plus_stream }

      it "stops within the damaged comment and recovers at the next comment boundary" do
        expect(source.errors).to be_empty
        expect(stream.errors.size).to eq(1)
        error = stream.errors.first
        expect(error).to be_a(Emf::ParseError)
        expect(error.offset).to eq(fixtures.plus_header.bytesize + fixtures.typed_record(:Clear).bytesize)
        expect(stream.records.map { |handle| handle.record.type }).to eq([0x4001, 0x4009, 0x4009, 0x4002])
        expect(stream.records.map(&:segment_index)).to eq([0, 0, 1, 1])
        expect(stream.segments.first.unframed).to eq(malformed + fixtures.typed_record(:Clear))
        expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
      end

      it "keeps the damaged bytes and later comment when a preceding record is edited" do
        handle = stream.records.fetch(1)
        edited = stream.edit { |editor| editor.replace(handle, handle.record.with(color: { red: 123 })) }
        reparsed = Emf.parse(Emf.serialize(edited)).emf_plus_stream

        expect(reparsed.records.fetch(1).record.color.red).to eq(123)
        expect(reparsed.segments.first.unframed).to eq(stream.segments.first.unframed)
        expect(reparsed.segments.last.payload).to eq(stream.segments.last.payload)
        expect(reparsed.errors.map(&:message)).to eq(stream.errors.map(&:message))
        expect(Emf.serialize(source)).to eq(bytes)
      end
    end
  end
end
