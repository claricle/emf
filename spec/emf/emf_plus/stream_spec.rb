# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Stream do
  include Emf::SpecSupport::EmfPlusRecords

  let(:fixture_paths) { Dir[File.join(__dir__, "../../fixtures/**/*.emf")].sort }
  let(:emf_plus_fixtures) do
    fixture_paths.filter_map do |path|
      bytes = File.binread(path)
      metafile = parse_or_nil(bytes)
      [path, bytes, metafile] if metafile&.format == :emf_plus
    end
  end
  let(:bytes) { File.binread(File.join(__dir__, "../../fixtures/emf/test-000.emf")) }
  let(:metafile) { Emf.parse(bytes) }
  let(:stream) { metafile.emf_plus_stream }

  def parse_or_nil(bytes)
    Emf.parse(bytes)
  rescue Emf::FormatError
    nil
  end

  def identity_matrix_edit(handle)
    handle.record.with(matrix: { m11: 2.0, m12: 0.0, m21: 0.0, m22: 2.0, dx: 5.0, dy: 0.0 })
  end

  def world_transform = stream.each_record.find { |h| h.record.is_a?(Emf::EmfPlus::Records::SetWorldTransform) }

  def comment_wire(payload)
    data = "EMF+".b + payload
    Emf::Emr::Binary::Records::Comment.new(i_type: 70, n_size: 12 + data.bytesize + (-data.bytesize % 4),
                                           cb_data: data.bytesize, data: data + ("\0" * (-data.bytesize % 4)))
  end

  def with_comments(source, *payloads)
    adapters = payloads.map { |payload| Emf::Model::Emr::Records::WireAdapter.new(wire: comment_wire(payload)) }
    Emf::Model::Metafile.new(format: :emf_plus, header: source.header, records: adapters + source.records.last(1),
                             emf_plus: payloads.join, trailing: source.trailing)
  end

  def reparse(metafile) = Emf.parse(Emf.serialize(metafile))

  it "round-trips every EMF+ fixture byte for byte when unedited" do
    expect(emf_plus_fixtures.size).to be >= 27
    emf_plus_fixtures.each do |path, original, parsed|
      edited_free = parsed.emf_plus_stream.to_metafile
      expect(edited_free).to equal(parsed), path
      expect(Emf.serialize(edited_free)).to eq(Emf.serialize(parsed)), path
      expect(Emf.serialize(edited_free)).to eq(original), path unless path.include?("emf-corrupted")
    end
  end

  it "lays segments over the EMF+ comments and entries in file order" do
    expect(stream.segments.size).to eq(28)
    stream.segments.each do |segment|
      wire = metafile.records[segment.record_index].wire
      expect(wire.data.byteslice(segment.payload_range)).to eq(segment.payload)
      expect(segment).not_to be_dirty
    end
    expect(stream.segments.sum { |s| s.payload.bytesize }).to eq(metafile.emf_plus.bytesize)
    expect(stream.records.map(&:stream_index)).to eq((0...stream.records.size).to_a)
    expect(stream.records.map(&:record)).to all(respond_to(:to_binary))
  end

  it "gives each record its segment index and payload offset" do
    segment_one = stream.records.select { |h| h.segment_index == 1 }
    expect(segment_one.first.offset).to eq(0)
    steps = segment_one.each_cons(2).map { |a, b| b.offset - a.offset }
    expect(steps).to eq(segment_one.first(segment_one.size - 1).map { |h| h.record.size })
  end

  it "places EMF gaps between the EMF+ comments, covering every EMF record once" do
    covered = stream.entries.flat_map { |e| e.gap? ? e.range.to_a : [stream.segments[e.segment_index].record_index] }.uniq
    expect(covered.sort).to eq((0...metafile.records.size).to_a)
    expect(stream.entries.select(&:gap?).map(&:range)).to all(satisfy { |r| r.size.positive? })
  end

  it "replaces one record and rebuilds only its segment's comment" do
    handle = world_transform
    edited = stream.edit { |editor| editor.replace(handle, identity_matrix_edit(handle)) }
    index = stream.segments[handle.segment_index].record_index

    changed = metafile.records.each_index.reject { |i| edited.records[i].equal?(metafile.records[i]) }
    expect(changed).to eq([index])
    expect(edited.header.n_bytes).to eq(metafile.header.n_bytes)
    reread = reparse(edited).emf_plus_stream.records[handle.stream_index].record
    expect(reread.matrix.m11).to eq(2.0)
    expect(reread.matrix.dx).to eq(5.0)
    expect(stream.records[handle.stream_index].record.matrix.m11).to eq(1.0)
  end

  it "does not change the stream or source on with_record" do
    handle = world_transform
    edited = stream.with_record(handle, identity_matrix_edit(handle))
    expect(edited.segments[handle.segment_index]).to be_dirty
    expect(stream.segments[handle.segment_index]).not_to be_dirty
    expect(edited.source).to equal(metafile)
    expect(Emf.serialize(metafile)).to eq(bytes)
  end

  it "recomputes sizes and the header when an edit grows the segment" do
    handle = world_transform
    frame = Emf::EmfPlus::Frame.new(type: handle.record.type, flags: 0, size: 12 + 24 + 8, data_size: 32,
                                    data: handle.record.body.to_binary_s + ("\1" * 8))
    edited = stream.edit { |e| e.replace(handle, Emf::EmfPlus::Records::Unknown.new(frame)) }
    expect(edited.header.n_bytes).to eq(metafile.header.n_bytes + 8)
    expect(Emf.serialize(edited).bytesize).to eq(bytes.bytesize + 8)
    expect(reparse(edited).emf_plus_stream.errors).to eq(stream.errors)
  end

  it "keeps bytes after cb_data as the segment tail through a rebuild" do
    source = with_comments(metafile, record(0x4001, "\0" * 4) + "\xAA\xBB\xCC\xDD".b)
    wire = source.records.first.wire
    wire.cb_data = 4 + 16
    segment = source.emf_plus_stream.segments.first
    expect(segment.tail).to eq("\xAA\xBB\xCC\xDD".b)
    expect(segment.payload.bytesize).to eq(16)
  end

  context "when the source comments changed" do
    it "is stale, raises on edit and to_metafile, and still reads" do
      handle = world_transform
      replacement = identity_matrix_edit(handle)
      segment = stream.segments[handle.segment_index]
      metafile.records[segment.record_index].wire.data = "EMF+".b + ("\0" * 4)

      expect(stream).to be_stale
      expect { stream.with_record(handle, replacement) }.to raise_error(Emf::EmfPlus::StaleStreamError)
      expect { stream.to_metafile }.to raise_error(Emf::Error)
      expect(stream.records.size).to be > 1
      expect(metafile.emf_plus_stream(reload: true)).not_to be_stale
    end

    it "is fresh when nothing changed" do
      expect(stream).not_to be_stale
    end
  end

  context "when an EMF+ comment is malformed" do
    let(:truncated) { record(0x4001, "\0" * 16)[0, 20] }
    let(:broken) { with_comments(metafile, truncated) }

    it "parses, reports a diagnostic in stream.errors only, and preserves the bytes" do
      source = reparse(broken)
      expect(source.errors).to be_empty
      expect(source.emf_plus_stream.errors.first).to be_a(Emf::ParseError)
      expect(source.emf_plus_stream.segments.first.payload).to eq(truncated)
      expect(Emf.serialize(source.emf_plus_stream.to_metafile)).to eq(Emf.serialize(broken))
    end

    it "falls back to an unknown record for an undecodable body" do
      bad = record(Emf::EmfPlus::Records::SetWorldTransform::TYPE, "\0" * 4)
      source = reparse(with_comments(metafile, bad))
      expect(source.emf_plus_stream.errors).not_to be_empty
      expect(Emf.serialize(source.emf_plus_stream.to_metafile)).to eq(Emf.serialize(source))
    end
  end

  context "when a record spans two comments" do
    it "keeps both halves raw with diagnostics and loses no bytes" do
      whole = record(0x402A, "\0" * 24)
      source = reparse(with_comments(metafile, whole[0, 20], whole[20..]))
      stream = source.emf_plus_stream
      expect(stream.errors).not_to be_empty
      expect(stream.segments.map(&:payload).join).to eq(whole)
      expect(Emf.serialize(stream.to_metafile)).to eq(Emf.serialize(source))
    end
  end

  describe "Metafile#emf_plus_stream" do
    it "is memoised and rebuilt with reload" do
      expect(metafile.emf_plus_stream).to equal(metafile.emf_plus_stream)
      first = metafile.emf_plus_stream
      reloaded = metafile.emf_plus_stream(reload: true)
      expect(reloaded).not_to equal(first)
      expect(metafile.emf_plus_stream).to equal(reloaded)
    end

    it "is nil for plain EMF and WMF" do
      paths = Dir[File.join(__dir__, "../../fixtures/emf/*.emf")]
      plain = paths.map { |p| [p, File.binread(p)] }.find { |_, b| Emf.parse(b).format == :emf }
      wmf = Dir[File.join(__dir__, "../../fixtures/wmf/*.wmf")].first
      expect(Emf.parse(File.binread(plain.first)).emf_plus_stream).to be_nil
      expect(Emf.parse(File.binread(wmf)).emf_plus_stream).to be_nil
    end

    it "leaves Metafile#emf_plus raw" do
      stream
      expect(metafile.emf_plus).to be_a(String)
    end
  end

  describe "representation" do
    def stream_of(name) = Emf.parse_file(File.expand_path("../../fixtures/emf/#{name}.emf", __dir__)).emf_plus_stream

    def world_transform_in(stream)
      stream.each_record.find { |h| h.record.is_a?(Emf::EmfPlus::Records::SetWorldTransform) }
    end

    def frames_of(stream)
      Emf::EmfPlus::Parser.from_metafile(stream.source)
    end

    it "links both E-flag draws of test-038 to their SerializableObject" do
      s = stream_of("test-038")
      draws = s.each_record.select { |h| h.record.is_a?(Emf::EmfPlus::Records::DrawImagePoints) && h.record.flags.anybits?(0x2000) }

      expect(draws.size).to eq(2)
      draws.each do |draw|
        effect = s.effect_for(draw)
        expect(effect.record).to be_a(Emf::EmfPlus::Records::SerializableObject)
        expect(effect.stream_index).to eq(draw.stream_index - 1)
      end
      expect(s.effect_for(world_transform)).to be_nil
      expect(s.errors).to be_empty
    end

    %w[test-109 test-155].each do |name|
      it "resolves #{name} DrawImagePoints image and attributes through the stream" do
        s = stream_of(name)
        draws = s.each_record.select { |h| h.record.is_a?(Emf::EmfPlus::Records::DrawImagePoints) }
        resolved = draws.flat_map { |h| s.resolve(h) }

        expect(draws).not_to be_empty
        expect(resolved.map(&:role).uniq).to eq(%i[image image_attributes])
        expect(resolved.select { |r| r.role == :image }.map(&:diagnostic)).to all(be_nil)
        expect(resolved.select { |r| r.role == :image }.map { |r| r.object.object_type }.uniq).to eq([Emf::EmfPlus::Objects::IMAGE])
        expect(s.objects).to equal(s.objects)
      end
    end

    it "gives as many dc_spans as Links finds GetDC frames" do
      s = stream_of("test-109")
      expected = Emf::EmfPlus::Links.get_dc_spans(s.source, frames_of(s))

      expect(s.dc_spans.size).to eq(7)
      expect(s.dc_spans.map(&:to_a)).to eq(expected.map(&:to_a))
    end

    it "merges link diagnostics into stream.errors only, after an edit unlinks an effect" do
      s = stream_of("test-038")
      draw = s.each_record.find { |h| h.record.is_a?(Emf::EmfPlus::Records::DrawImagePoints) && h.record.flags.anybits?(0x2000) }
      effect = s.effect_for(draw)
      edited = s.with_record(effect, world_transform_in(s).record)
      edited_draw = edited.each_record.find { |h| h.stream_index == draw.stream_index }

      expect(edited.effect_for(edited_draw)).to be_nil
      expect(edited.errors.map(&:reason)).to eq([:missing_effect])
      expect(edited.objects.errors).to be_empty
      expect(edited.source.errors).to eq(s.source.errors)
      expect(s.errors).to be_empty
    end

    it "rebuilds objects and dc_spans from the edited records" do
      s = stream_of("test-109")
      draw = s.each_record.find { |h| h.record.is_a?(Emf::EmfPlus::Records::DrawImagePoints) }
      s.objects
      s.dc_spans
      edited = s.with_record(draw, draw.record.with(image_object_id: 62))
      edited_draw = edited.each_record.find { |h| h.stream_index == draw.stream_index }

      expect(edited.objects).not_to equal(s.objects)
      expect(edited.resolve(edited_draw).first.diagnostic.kind).to eq(:empty_slot)
      expect(s.resolve(draw).first.diagnostic).to be_nil
      expect(edited.dc_spans.size).to eq(s.dc_spans.size)
    end
  end
end
