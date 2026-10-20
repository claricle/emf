# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/emf_plus_native_snapshot"

RSpec.describe "EMF+ EPSN segment and public stream parity" do
  include_context "with native library"

  let(:fixtures) { Emf::SpecSupport::EmfPlusGeneratedFixtures }
  let(:parity) { Emf::SpecSupport::EmfPlusSegmentParity }
  let(:snapshot_reader) { Emf::SpecSupport::EmfPlusNativeSnapshot.new(library) }
  let(:clear) { fixtures.record(0x4009, [0x80FF0033].pack("V")) }
  let(:opaque) { fixtures.record(0x7FFF, "raw!PAD!", flags: 0x1234, data_size: 4) }
  let(:ruby_file) { parity.parse(input, "ruby", library) }
  let(:native_file) { parity.parse(input, "native", library) }
  let(:ruby_stream) { ruby_file.emf_plus_stream }
  let(:native_stream) { native_file.emf_plus_stream }

  shared_examples "matching EPSN segments" do
    it "maps each source comment and exact logical payload to the Ruby segments" do
      snapshot = snapshot_reader.call(input)
      count = snapshot.byteslice(16, 8).unpack1("Q<")
      rows = Array.new(count) { |index| snapshot.byteslice(40 + (index * 32), 32).unpack("Q<4") }
      expect(snapshot.byteslice(0, 16)).to eq("EPSN".b + [1, snapshot.bytesize].pack("VQ<"))
      expect(rows).to eq(parity.segment_rows(ruby_stream))
      expect(rows.map(&:first)).to eq(payloads.each_index.map { |index| (index * 2) + 1 })
      expect(rows.map { |row| row[2] }).to eq(payloads.map(&:bytesize))
      expect(rows.map(&:last)).to all(eq(4))
      rows.zip(ruby_stream.segments, payloads).each do |row, segment, payload|
        wire = ruby_file.records.fetch(row.first).wire
        expect(wire.data.to_s.b.byteslice(row.last, row[2])).to eq(payload)
        expect(segment.payload).to eq(payload)
        expect(segment.tail).to eq("#{"\xA5".b * (-(payload.bytesize + 4) % 4)}TAIL".b)
      end
      expect(parity.frames(snapshot).map { |frame| frame.fetch(:raw) }.join.b).to eq(payloads.join.b)
      expect(Emf.serialize(ruby_file)).to eq(input)
    end
  end

  context "with empty comments, outer gaps and split frame headers/bodies" do
    let(:logical) { clear + opaque }
    let(:payloads) { ["".b, logical.byteslice(0, 7), logical.byteslice(7, 23), "".b, logical.byteslice(30..)] }
    let(:input) { parity.file(payloads) }

    include_examples "matching EPSN segments"

    it "retains typed native frame values and the existing Ruby diagnostics through both backends" do
      frames = parity.frames(snapshot_reader.call(input))
      expect(frames.map { |frame| frame.fetch(:range) }).to eq([[0, 1, 2], [16, 2, 4]])
      expect(frames.map { |frame| frame.fetch(:family) }).to eq([3, 0])
      expect(frames.first.fetch(:typed)).to eq([0x80FF0033].pack("V"))
      expect(frames.last.fetch(:raw)).to eq(opaque)
      expect(ruby_stream.errors.map(&:message).join).to include("truncated EMF+ record header", "cannot span comments")
      expect(parity.view(native_stream)).to eq(parity.view(ruby_stream))
      expect(native_stream.to_metafile).to equal(native_file)
      expect(Emf.serialize(native_file)).to eq(input)
    end
  end

  context "with whole typed records and opaque padding" do
    let(:payloads) { ["".b, fixtures.plus_header + clear + opaque, fixtures.plus_eof, "".b] }
    let(:input) { parity.file(payloads) }

    include_examples "matching EPSN segments"

    it "exposes matching typed values, gaps and nonmutating edits with exact neighbor preservation" do
      # Prove forced native dispatch does not fall back to the Ruby outer parser.
      ruby_stream.records
      expect(Emf::Emr::Parser).not_to receive(:call)
      expect(parity.view(native_stream)).to eq(parity.view(ruby_stream))
      expect(native_stream.errors.map(&:kind)).to eq(%i[unknown_type header_not_after_emf_header])
      expect(native_stream.entries.select(&:gap?).map(&:range)).to eq([0...1, 2...3, 4...5, 6...7, 8...10])
      expect(native_stream.records.map { |handle| handle.record.class }).to eq(
        [Emf::EmfPlus::Records::Header, Emf::EmfPlus::Records::Clear,
         Emf::EmfPlus::Records::Unknown, Emf::EmfPlus::Records::EndOfFile]
      )
      results = [ruby_stream, native_stream].map do |stream|
        handle = stream.records.fetch(1)
        expect(handle.record.color.red).to eq(255)
        edited = stream.edit { |editor| editor.replace(handle, handle.record.with(color: { red: 9 })) }
        expect(stream).not_to be_dirty
        expect(stream.to_metafile).to equal(stream.source)
        expect(Emf.serialize(stream.source)).to eq(input)
        expect(edited.emf_plus_stream.records.fetch(1).record.color.red).to eq(9)
        edited.records.each_with_index do |record, index|
          next if index == 3

          expect(record.to_binary_s).to eq(stream.source.records.fetch(index).to_binary_s)
        end
        expect(edited.emf_plus_stream.segments.fetch(1).tail).to eq(stream.segments.fetch(1).tail)
        expect(edited.emf_plus_stream.records.fetch(2).record.to_binary).to eq(opaque)
        Emf.serialize(edited)
      end
      expect(results.last).to eq(results.first)
      expect(results.first).not_to eq(input)
    end
  end
end
