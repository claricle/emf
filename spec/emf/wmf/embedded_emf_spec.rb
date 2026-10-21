# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_embedded_emf"

RSpec.describe Emf::Wmf::EmbeddedEmf do
  include WmfEmbeddedEmfSupport

  let(:emf_bytes) { File.binread(File.expand_path("../../fixtures/emf/test-030.emf", __dir__)) }
  let(:stream) { (0...20_000).map { |i| ((i * 7) + 3) & 0xFF }.pack("C*") }

  def reason_for(records)
    described_class.assemble(records)
    nil
  rescue described_class::Invalid => e
    e.reason
  end

  def segment_reason(record)
    described_class.segment(record)
    nil
  rescue described_class::Invalid => e
    e.reason
  end

  describe ".assemble" do
    it "assembles a single segment into EMF bytes that Emf.parse reads and re-serializes identically" do
      records = embedded_escapes(emf_bytes, 8192)
      result = described_class.assemble(records)

      expect([records.size, result.bytes, result.checksum_valid, result.version]).to eq([1, emf_bytes, true, 0x00010000])
      expect(Emf.serialize(Emf.parse(result.bytes))).to eq(emf_bytes)
    end

    it "concatenates multiple segments in order and parses the result" do
      records = embedded_escapes(emf_bytes, 100)
      result = described_class.assemble(records)

      expect([records.size, result.bytes]).to eq([3, emf_bytes])
      expect(Emf.parse(result.bytes).format).to eq(:emf)
    end

    it "accepts segments at the 8,192-byte limit and a final short segment" do
      records = embedded_escapes(stream, 8192)

      expect([records.size, described_class.assemble(records).bytes]).to eq([3, stream])
      exact = stream.byteslice(0, 8192)
      expect(described_class.assemble(embedded_escapes(exact, 8192)).bytes).to eq(exact)
    end

    it "reports a wrong checksum without rejecting the stream" do
      records = embedded_escapes(emf_bytes, 8192)
      records.first.data = records.first.data.dup.tap { |data| data.setbyte(12, data.getbyte(12) ^ 1) }

      expect(described_class.assemble(records).checksum_valid).to be(false)
    end

    it "rejects an incomplete or empty sequence" do
      records = embedded_escapes(stream, 8192)

      expect([reason_for(records.first(2)), reason_for([])]).to eq(%i[incomplete incomplete])
    end

    it "rejects segments after completion and a count that disagrees with the bytes" do
      records = embedded_escapes(stream, 8192)
      short = embedded_escapes(stream, 8192).each { |r| r.data = r.data.dup.tap { |d| d.setbyte(18, 2) } }

      expect(reason_for(records + [records.first])).to eq(:record_count_mismatch)
      expect(reason_for(short)).to eq(:record_count_mismatch)
    end

    it "rejects reordered segments, changed totals and changed counts" do
      records = embedded_escapes(stream, 8192)
      totals = embedded_escapes(stream, 8192).tap { |r| r[1].data = r[1].data.dup.tap { |d| d.setbyte(30, d.getbyte(30) ^ 1) } }
      counts = embedded_escapes(stream, 8192).tap { |r| r[2].data = r[2].data.dup.tap { |d| d.setbyte(18, 9) } }

      expect(reason_for(records.values_at(1, 0, 2))).to eq(:remaining_mismatch)
      expect(reason_for(totals)).to eq(:sequence_mismatch)
      expect(reason_for(counts)).to eq(:sequence_mismatch)
    end

    it "refuses a declared total above max_bytes before copying" do
      expect { described_class.assemble(embedded_escapes(stream, 8192), max_bytes: 100) }
        .to raise_error(described_class::Invalid) { |e| expect(e.reason).to eq(:limit_exceeded) }
    end
  end

  describe ".segment" do
    let(:good) { embedded_segment_data("abcd".b, count: 1, total: 4, remaining: 0) }

    it "returns the validated metadata and data" do
      segment = described_class.segment(embedded_escape(good))

      expect(segment.to_h).to eq(version: 0x00010000, checksum: 0, flags: 0, record_count: 1, current_size: 4,
                                 remaining_bytes: 0, total_size: 4, data: "abcd".b)
    end

    it "validates through the record view" do
      expect(embedded_escape(good).embedded_emf_segment.data).to eq("abcd".b)
    end

    it "rejects malformed metadata with a reason" do
      reasons = { identifier: 1, type: 2, flags: 1, count: 0 }.map do |key, value|
        segment_reason(embedded_escape(embedded_segment_data("abcd".b, count: 1, total: 4, remaining: 0, **{ key => value })))
      end

      expect(reasons).to eq(%i[comment_identifier comment_type non_zero_flags zero_record_count])
    end

    it "rejects truncated metadata, a ByteCount that disagrees with CurrentRecordSize, and bad alignment" do
      expect(segment_reason(embedded_escape(good.byteslice(0, 32)))).to eq(:metadata)
      mismatch = embedded_escape(embedded_segment_data("abcd".b, count: 1, total: 8, remaining: 0, current: 7))
      expect(segment_reason(mismatch)).to eq(:metadata)
      expect(segment_reason(embedded_escape(good, padding: 0))).to eq(:transport)
      odd = embedded_escape(embedded_segment_data("abc".b, count: 1, total: 3, remaining: 0)).tap { |r| r.padding = nil }
      expect(segment_reason(odd)).to eq(:transport)
    end

    it "rejects an oversize segment and sizes beyond the declared total" do
      big = embedded_escape(embedded_segment_data("x".b * 8194, count: 1, total: 8194, remaining: 0))
      beyond = embedded_escape(embedded_segment_data("abcd".b, count: 1, total: 2, remaining: 0))

      expect([segment_reason(big), segment_reason(beyond)]).to eq(%i[segment_too_large inconsistent_sizes])
    end

    it "rejects other escapes and other subtypes" do
      other = Emf::Model::Wmf::Records::Escape.new(escape_function: 0x0013, data: good, padding: nil)

      expect(segment_reason(other)).to eq(:not_embedded_emf)
    end
  end

  describe ".sequences" do
    it "finds each run in a parsed document and leaves serialization byte-identical" do
      first = embedded_escapes(stream, 8192)
      second = embedded_escapes(emf_bytes, 8192)
      broken = embedded_escape(embedded_segment_data("abcd".b, count: 1, total: 4, remaining: 0, type: 9))
      wire = [*first, native_wmf_record(0x001E, "".b), *second, broken].map { |r| r.is_a?(String) ? r : wire_escape(r) }
      bytes = native_wmf_bytes(wire)
      metafile = Emf::Wmf::Parser.call(bytes)
      sequences = described_class.sequences(metafile.records)

      expect(sequences.map { |s| [s.first_record, s.segment_count, s.error] }).to eq([[0, 3, nil], [4, 1, nil], [5, 1, :comment_type]])
      expect([sequences[0].stream.bytes, sequences[1].stream.bytes]).to eq([stream, emf_bytes])
      expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
    end
  end

  context "with the native backend" do
    around do |example|
      previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
      ENV["EMF_BACKEND"] = "native"
      ENV["EMF_NATIVE_LIBRARY"] = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "")
      example.run
    ensure
      ENV["EMF_BACKEND"] = previous["EMF_BACKEND"]
      ENV["EMF_NATIVE_LIBRARY"] = previous["EMF_NATIVE_LIBRARY"]
    end

    it "assembles from hydrated records and matches the Ruby parser" do
      skip "set EMF_TEST_NATIVE_LIBRARY to test native WMF" unless File.file?(ENV.fetch("EMF_NATIVE_LIBRARY"))

      bytes = native_wmf_bytes(embedded_escapes(emf_bytes, 100).map { |record| wire_escape(record) })
      sequences = described_class.sequences(Emf.parse(bytes).records)

      expect(sequences.map { |s| [s.first_record, s.segment_count, s.error] }).to eq([[0, 3, nil]])
      expect(sequences.first.stream.bytes).to eq(emf_bytes)
    end
  end
end
