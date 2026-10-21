# frozen_string_literal: true

require "spec_helper"
require "emf/native/emf_plus_stream"
require_relative "../../support/native_library_context"
require_relative "../../support/emf_plus_generated_fixtures"
require_relative "../../support/emf_plus_native_stream_support"

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
        next if support::NATIVE_FALLBACK.include?(path)

        native = native_for(File.binread(path), metafile)
        expect(native).to be_a(described_class), path
        expect(support.view(native)).to eq(support.view(metafile.emf_plus_stream)), path
        expect(native.objects.errors.map(&:message)).to eq(metafile.emf_plus_stream.objects.errors.map(&:message)), path
      end
    end

    it "round-trips the source bytes exactly, unedited and through an identity edit" do
      emf_plus.each do |path, metafile|
        next if support::NATIVE_FALLBACK.include?(path)

        bytes = File.binread(path)
        native = native_for(bytes, metafile)
        expect(native.to_metafile).to equal(metafile), path
        expect(Emf::Emr::Serializer.call(native.to_metafile)).to eq(bytes), path
        expect(native.segments.sum { |segment| segment.payload.bytesize }).to eq(native.snapshot.frames.sum(&:frame_size)), path
        expect(native.snapshot.frames.map(&:raw).join.b).to eq(native.records.map { |handle| handle.record.to_binary }.join.b), path
        first = native.records.first
        expect(Emf::Emr::Serializer.call(native.edit { |editor| editor.replace(first, first.record) })).to eq(bytes), path
      end
    end

    it "reports the same unresolved references natively as the Ruby object table" do
      emf_plus.each do |path, metafile|
        next if support::NATIVE_FALLBACK.include?(path)

        native = native_for(File.binread(path), metafile)
        expect(support.native_diagnostics(native)).to eq(support.ruby_diagnostics(native)), path
      end
    end

    it "falls back (nil) exactly for the documented fixtures, leaving the Ruby stream in charge" do
      fallback = emf_plus.keys.select { |path| native_for(File.binread(path), emf_plus.fetch(path)).nil? }
      expect(fallback).to match_array(support::NATIVE_FALLBACK)
      fallback.each { |path| expect(emf_plus.fetch(path).emf_plus_stream).to be_a(Emf::EmfPlus::Stream) }
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
    it "returns nil for a malformed frame, which Ruby keeps as a diagnosed Unknown record" do
      bytes = fixtures.malformed_comment_file(fixtures.malformed_frames.fetch(:size_below_header))
      metafile = support.ruby_parse(bytes)
      expect(native_for(bytes, metafile)).to be_nil
      expect(metafile.emf_plus_stream.errors).not_to be_empty
    end

    it "returns nil for a frame that crosses comments" do
      logical = fixtures.plus_header + fixtures.typed_record(:Clear) + fixtures.plus_eof
      bytes = fixtures.emf_file([logical.byteslice(0, 30), logical.byteslice(30..)])
      expect(native_for(bytes)).to be_nil
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
      expect { described_class.new(buffer.dup.tap { |copy| copy[4, 4] = [2].pack("V") }) }.to raise_error(Emf::FormatError, /version/)
      huge = buffer.dup.tap { |copy| copy[24, 8] = [1 << 40].pack("Q<") }
      expect { described_class.new(huge) }.to raise_error(Emf::FormatError, /exceeds/)
    end
  end
end
