# frozen_string_literal: true

require "spec_helper"
require "emf/native/emf_plus_stream"
require_relative "../../support/native_library_context"
require_relative "../../support/emf_plus_generated_fixtures"
require_relative "../../support/emf_plus_native_stream_support"
require_relative "../../support/emf_plus_native_snapshot"

RSpec.describe Emf::Native::EmfPlusStream do
  include_context "with native library"

  let(:support) { Emf::SpecSupport::EmfPlusNativeStreamSupport }
  let(:fixtures) { Emf::SpecSupport::EmfPlusGeneratedFixtures }

  def native_for(bytes, metafile = support.ruby_parse(bytes))
    described_class.from_metafile(metafile, bytes: bytes, library: library)
  end

  describe "parity with the Ruby Stream over every EMF+ fixture" do
    let(:parsed) { support.fixture_paths.to_h { |path| [path, support.try_parse(File.binread(path))] } }
    let(:emf_plus) { parsed.select { |_path, metafile| metafile&.format == :emf_plus } }

    it "finds the EMF+-bearing fixtures" do
      expect(emf_plus.size).to eq(27)
    end

    it "builds the same segments, records, gaps, errors and object diagnostics as Ruby" do
      emf_plus.each do |path, metafile|
        native = native_for(File.binread(path), metafile)
        expect(native).to be_a(described_class), path
        expect(support.view(native)).to eq(support.view(metafile.emf_plus_stream)), path
        expect(native.objects.errors.map(&:message)).to eq(metafile.emf_plus_stream.objects.errors.map(&:message)), path
      end
    end

    it "round-trips the source bytes exactly, unedited and through an identity edit" do
      emf_plus.each do |path, metafile|
        bytes = File.binread(path)
        native = native_for(bytes, metafile)
        expect(native.to_metafile).to equal(metafile), path
        expect(Emf::Emr::Serializer.call(native.to_metafile)).to eq(bytes), path
        framed = native.segments.sum { |segment| segment.payload.bytesize - segment.unframed.bytesize }
        expect(framed).to eq(native.snapshot.frames.sum(&:frame_size)), path
        expect(native.snapshot.frames.map(&:raw).join.b).to eq(native.records.map { |handle| handle.record.to_binary }.join.b), path
        first = native.records.first
        expect(Emf::Emr::Serializer.call(native.edit { |editor| editor.replace(first, first.record) })).to eq(bytes), path
      end
    end

    it "reports the same unresolved references natively as the Ruby object table" do
      emf_plus.each do |path, metafile|
        native = native_for(File.binread(path), metafile)
        expect(support.native_diagnostics(native)).to eq(support.ruby_diagnostics(native)), path
      end
    end

    it "adopts every EMF+ fixture natively, including the corrupted ones, with no fallback" do
      fallback = emf_plus.keys.select { |path| native_for(File.binread(path), emf_plus.fetch(path)).nil? }
      expect(fallback).to eq([])
    end

    it "keeps Ruby's framing error and unframed bytes for a malformed header in a corrupted fixture" do
      path = "spec/fixtures/emf-corrupted/bad_corrupted_2014-12-07-163010.emf"
      native = native_for(File.binread(path), emf_plus.fetch(path))
      expect(native.segments.sum { |segment| segment.unframed.bytesize }).to eq(52)
      expect(native.errors.map(&:message)).to eq(["EMF+ record DataSize 4009754664 exceeds Size 52 - 12 at offset 0"])
    end

    it "clamps an EMR_COMMENT whose cbData exceeds its record, as Ruby does" do
      path = "spec/fixtures/emf-corrupted/bad_corrupted_2017-02-11-230400.emf"
      native = native_for(File.binread(path), emf_plus.fetch(path))
      expect(native.segments.map(&:record_index)).to include(8)
      expect(native.segments.find { |segment| segment.record_index == 8 }.payload.bytesize).to eq(64)
    end
  end

  describe "the family mapping of every Ruby record class" do
    let(:samples) do
      support.fixture_paths.map { |path| File.binread(path) } << fixtures.combined_file
    end
    let(:observed) do
      samples.each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |bytes, seen|
        metafile = support.try_parse(bytes)
        next unless metafile&.format == :emf_plus

        native = native_for(bytes, metafile) or next
        native.records.each { |handle| seen[handle.record.class] << native.native_family(handle) }
      end
    end

    it "gives each Ruby record class one native family, as the Rust ABI documents" do
      expect(observed.transform_values(&:to_a)).to eq(support::FAMILY_BY_CLASS.transform_values { |family| [family] }
        .slice(*observed.keys))
    end

    it "covers every record class the Ruby registry decodes" do
      expect(Emf::EmfPlus::Records.registry.values - observed.keys).to eq([])
    end

    it "carries a fixed-width typed payload equal to the Ruby record body for the fixed families" do
      native = native_for(fixtures.combined_file)
      checked = native.records.select { |handle| (1..10).cover?(Emf::Native::EmfPlusSnapshot::FAMILIES.key(native.native_family(handle))) }
      expect(checked).not_to be_empty
      checked.each do |handle|
        frame = native.snapshot.frames.fetch(handle.stream_index)
        expect(frame.typed).to eq(handle.record.to_binary.byteslice(12, frame.typed.bytesize)), handle.record.class.name
      end
    end
  end

  describe "SetTSClip across the snapshot" do
    let(:ts_clip) { fixtures.klass(:SetTSClip)::TYPE }
    let(:rects) { [[1, -2, 300, 400], [-32_768, 0, 32_767, -1]] }
    let(:compressed_body) { [5, 6, 7, 8].pack("C*") }
    let(:bytes) do
      fixtures.single_comment(fixtures.record(ts_clip, rects.flatten.pack("s<*"), flags: rects.size),
                              fixtures.record(ts_clip, compressed_body, flags: 0x8001),
                              fixtures.record(ts_clip, "", flags: 0))
    end
    let(:native) { native_for(bytes) }
    let(:clips) { native.records.select { |handle| handle.record.is_a?(Emf::EmfPlus::Records::SetTSClip) } }

    it "types uncompressed rectangles, equal to the Ruby record's rects" do
      uncompressed = clips.reject { |handle| handle.record.compressed? }
      expect(uncompressed.map { |handle| native.native_family(handle) }).to eq(%i[ts_clip ts_clip])
      first, empty = uncompressed.map { |handle| native.snapshot.frames.fetch(handle.stream_index).typed }
      expect(first.unpack("Q<l<*")).to eq([2, *rects.flatten])
      expect(first.unpack("Q<l<*").drop(1).each_slice(4).to_a).to eq(uncompressed.first.record.rects)
      expect(empty.unpack("Q<")).to eq([0])
    end

    it "leaves compressed rectangles as raw bytes in the opaque family" do
      handle = clips.find { |candidate| candidate.record.compressed? }
      frame = native.snapshot.frames.fetch(handle.stream_index)
      expect([native.native_family(handle), frame.typed, frame.raw.byteslice(12, 4)]).to eq([:opaque, "".b, compressed_body])
      expect(handle.record.rects).to eq([])
    end

    it "is requested only by snapshot version 2, so a version 1 reader still sees the opaque family" do
      v1 = Emf::Native::EmfPlusSnapshot.new(Emf::SpecSupport::EmfPlusNativeSnapshot.new(library).call(bytes))
      expect(v1.frames.select { |frame| frame.type == ts_clip }.map(&:family).uniq).to eq([:opaque])
    end
  end

  describe "object-reference diagnostics on a synthetic stream" do
    let(:solid) { fixtures.object_record(1, 3, fixtures::VERSION + fixtures.u32(0, 0xFF112233)) }
    let(:attributes) { fixtures.object_record(8, 1, fixtures::VERSION + fixtures.u32(0, 0, 0xFF000000, 0, 0)) }
    let(:chunks) do
      body = fixtures::VERSION + fixtures.u32(0, 0xFF445566)
      [fixtures.record(0x4008, fixtures.u32(12) + body.byteslice(0, 4), flags: 0x8104),
       fixtures.record(0x4008, fixtures.u32(12) + body.byteslice(4, 8), flags: 0x8104)]
    end
    let(:bytes) do
      fixtures.single_comment(solid, attributes, support.fill(3), support.fill(2), support.fill(1), support.fill(70),
                              support.fill(0xFF00FF00, solid: true), *chunks, support.fill(4), solid, support.fill(3))
    end
    let(:native) { native_for(bytes) }

    it "matches Ruby's time-indexed resolution, kind for kind" do
      expect(native).to be_a(described_class)
      expect(support.native_diagnostics(native)).to eq(support.ruby_diagnostics(native))
      expect(native.reference_diagnostics.map(&:kind)).to eq(%i[empty_slot wrong_type object_id_out_of_range])
      expect(native.reference_diagnostics.map(&:id)).to eq([2, 1, 70])
    end

    it "keeps the unedited bytes and drops the snapshot on edit while staying a Ruby Stream" do
      handle = native.records.find { |candidate| candidate.record.is_a?(Emf::EmfPlus::Records::FillRects) }
      edited = native.with_record(handle, handle.record)
      expect(edited).to be_a(Emf::EmfPlus::Stream)
      expect(edited.snapshot).to be_nil
      expect(Emf::Emr::Serializer.call(native.to_metafile)).to eq(bytes)
    end
  end

  describe "when the native snapshot cannot stand in for the Ruby parse" do
    it "frames a malformed header as Ruby does: error, unframed rest, and the next comment unaffected" do
      fixtures.malformed_frames.each do |name, malformed|
        bytes = fixtures.malformed_comment_file(malformed)
        metafile = support.ruby_parse(bytes)
        native = native_for(bytes, metafile)
        expect(native).to be_a(described_class), name.to_s
        expect(metafile.emf_plus_stream.errors).not_to be_empty
        expect(support.view(native)).to eq(support.view(metafile.emf_plus_stream)), name.to_s
        expect(Emf::Emr::Serializer.call(native.to_metafile)).to eq(bytes), name.to_s
      end
    end

    it "returns nil for a correctly framed record whose typed layout native rejects, which Ruby keeps as Unknown" do
      bytes = fixtures.single_comment(fixtures.record(fixtures.klass(:Clear)::TYPE, "", data_size: 0))
      metafile = support.ruby_parse(bytes)
      expect(native_for(bytes, metafile)).to be_nil
      expect(metafile.emf_plus_stream.errors).not_to be_empty
    end

    it "frames a record that crosses comments as Ruby does: an error in each comment, nothing spanning" do
      logical = fixtures.plus_header + fixtures.typed_record(:Clear) + fixtures.plus_eof
      bytes = fixtures.emf_file([logical.byteslice(0, 30), logical.byteslice(30..)])
      metafile = support.ruby_parse(bytes)
      native = native_for(bytes, metafile)
      expect(native).to be_a(described_class)
      expect(metafile.emf_plus_stream.errors.map(&:message)).to include(/truncated EMF\+ record header/)
      expect(support.view(native)).to eq(support.view(metafile.emf_plus_stream))
    end

    it "returns nil without a library and for a non-EMF+ metafile" do
      bytes = fixtures.single_comment
      expect(described_class.from_metafile(support.ruby_parse(bytes), bytes: bytes, library: nil)).to be_nil
      plain = support.ruby_parse(File.binread("spec/fixtures/emf/test-001.emf"))
      expect(described_class.from_metafile(plain, library: library)).to be_nil
    end
  end

  describe Emf::Native::EmfPlusSnapshot do
    let(:buffer) { Emf::Native::EmfPlusLoader.new(library).emf_plus_snapshot(Emf::SpecSupport::EmfPlusGeneratedFixtures.combined_file) }

    it "rejects a snapshot whose length, magic, version or counts are inconsistent" do
      expect { described_class.new(buffer.byteslice(0, buffer.bytesize - 1)) }.to raise_error(Emf::FormatError, /length/)
      expect { described_class.new("XXXX#{buffer.byteslice(4..)}") }.to raise_error(Emf::FormatError, /not an EMF\+/)
      expect { described_class.new(buffer.dup.tap { |copy| copy[4, 4] = [3].pack("V") }) }.to raise_error(Emf::FormatError, /version/)
      huge = buffer.dup.tap { |copy| copy[24, 8] = [1 << 40].pack("Q<") }
      expect { described_class.new(huge) }.to raise_error(Emf::FormatError, /exceeds/)
    end
  end
end
