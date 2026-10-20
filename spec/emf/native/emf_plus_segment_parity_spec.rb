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

  context "with normalized typed families and documented opaque fallbacks" do
    let(:cases) { parity.typed_cases }
    let(:transform_bytes) { [-0.0, 0, 0, 1, 5, 6].pack("e6") }
    let(:palette_bytes) { [0x80FF0033, 0x00010203].pack("V2") }
    let(:text_bytes) { [0xD800, 0x0061, 0xFFFF].pack("v3") }
    let(:payloads) { [fixtures.plus_header, *cases.map(&:first), fixtures.plus_eof] }
    let(:input) { parity.file(payloads) }

    include_examples "matching EPSN segments"

    it "encodes every represented family with exact normalized values and original frames" do
      frames = parity.frames(snapshot_reader.call(input))
      expect(frames.size).to eq(cases.size + 2)
      expect(frames.first.values_at(:family, :typed)).to eq([1, fixtures.plus_header.byteslice(12..)])
      expect(frames.last.values_at(:family, :typed)).to eq([2, "".b])
      frames[1...-1].zip(cases).each do |frame, (raw, family, typed)|
        expect(frame.values_at(:family, :typed, :raw)).to eq([family, typed, raw])
      end
      expect(parity.view(native_stream)).to eq(parity.view(ruby_stream))
      expect(Emf.serialize(native_file)).to eq(input)
    end

    it "exposes typed object, effect, graphics, drawing and text values through both public backends" do
      [ruby_stream, native_stream].each do |stream|
        records = stream.records.map(&:record)
        brush = Emf::EmfPlus::Objects.decode(stream.objects.lookup(1, at: records.size))
        expect(brush.data.solid_color).to have_attributes(alpha: 128, red: 255, green: 0, blue: 51)
        unknown = Emf::EmfPlus::Objects.decode(stream.objects.lookup(2, at: records.size))
        expect(unknown).to be_a(Emf::EmfPlus::Objects::Opaque)
        expect(unknown.to_binary).to eq("OBJ!")
        expect(records.fetch(3).effect).to have_attributes(blur_radius: 2.5, expand_edge: 0xFFFFFFFF)
        expect(records.fetch(4).effect).to be_a(Emf::EmfPlus::Effects::Opaque)
        expect(records.fetch(4).effect.to_binary).to eq("FX!?")
        graphics = records[5..7]
        graphics.each do |record|
          expect(record).to have_attributes(anti_alias_mode: 255, render_origin_x: -32_768,
                                            render_origin_y: 32_767, text_contrast: 65_535)
          expect(record.world_to_device.map(&:to_binary_s).join).to eq(transform_bytes)
        end
        expect(graphics.map(&:palette?)).to eq([false, true, true])
        expect(graphics.map { |record| record.decoded_palette&.palette_count&.to_i }).to eq([nil, 0, 2])
        expect(graphics.last.decoded_palette.palette_entries.map(&:to_binary_s).join).to eq(palette_bytes)
        expect(records.fetch(8).rect).to have_attributes(x: -3, y: 4, width: 5, height: 6)
        expect(records.fetch(8)).to have_attributes(brush_id: 0x80FF0033, solid_color?: true)
        expect(records.fetch(9)).to have_attributes(font_object_id: 5, brush_id: 7, format_id: 8, length: 3)
        expect(records.fetch(9).body.string_data.to_s).to eq(text_bytes)
        expect(records.fetch(9).text).to eq("\uFFFDa\uFFFF")
        expect(records.fetch(10)).to have_attributes(compressed?: true, rect_count: 1, rect_data: "RAW!", rects: [])
      end
    end

    it "edits graphics state without changing typed neighbors, fallbacks, comment tails or the source" do
      results = [ruby_stream, native_stream].map do |stream|
        handle = stream.records.fetch(7)
        edited = stream.edit { |editor| editor.replace(handle, handle.record.with(render_origin_x: -9)) }
        expect(edited.emf_plus_stream.records.fetch(7).record.render_origin_x).to eq(-9)
        expect(stream.records.fetch(7).record.render_origin_x).to eq(-32_768)
        expect(stream).not_to be_dirty
        expect(Emf.serialize(stream.source)).to eq(input)
        edited.records.each_with_index do |record, index|
          next if index == (handle.segment_index * 2) + 1

          expect(record.to_binary_s).to eq(stream.source.records.fetch(index).to_binary_s)
        end
        expect(edited.emf_plus_stream.segments.map(&:tail)).to eq(stream.segments.map(&:tail))
        expect(edited.emf_plus_stream.records.reject { |entry| entry.stream_index == 7 }.map { |entry| entry.record.to_binary }).to eq(
          stream.records.reject { |entry| entry.stream_index == 7 }.map { |entry| entry.record.to_binary }
        )
        bytes = Emf.serialize(edited)
        expect(parity.parse(bytes, "ruby", library).emf_plus_stream.records.fetch(7).record.render_origin_x).to eq(-9)
        bytes
      end
      expect(results.last).to eq(results.first)
      expect(results.first).not_to eq(input)
    end
  end
end
