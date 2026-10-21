# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"
require_relative "../support/native_wmf_views"
require_relative "../support/native_wmf_view_vectors"

# The Ruby views are pure functions of the raw record fields, which native-backed records carry
# unchanged. This spec proves three decoders agree on identical bytes: the Ruby parser's records,
# native-backed records, and the Rust typed views exported over the C ABI.
RSpec.describe "Native WMF typed views" do
  include_context "native WMF bridge"
  include NativeWmfViewVectors

  let(:rust) { NativeWmfViews.new(library) }

  def ruby_views(record)
    case record
    when Emf::Model::Wmf::Records::BitBlt, Emf::Model::Wmf::Records::DibBitBlt, Emf::Model::Wmf::Records::StretchBlt,
         Emf::Model::Wmf::Records::DibStretchBlt, Emf::Model::Wmf::Records::SetDibToDev, Emf::Model::Wmf::Records::StretchDib
      [record.typed_image].compact
    when Emf::Model::Wmf::Records::DibCreatePatternBrush then [record.target_dib].compact
    when Emf::Model::Wmf::Records::Escape then escape_views(record)
    else []
    end
  end

  def escape_views(record)
    views = [record.typed_payload, record.typed_counted_payload, record.typed_special_passthrough2_payload]
    views << embedded_segment(record) if Emf::Wmf::EmbeddedEmf.escape?(record)
    views.compact
  end

  def embedded_segment(record)
    record.embedded_emf_segment
  rescue Emf::Wmf::EmbeddedEmf::Invalid => e
    e.reason
  end

  def native_records(bytes)
    Emf.parse(bytes).records
  end

  def ruby_records(bytes)
    Emf::Wmf::Parser.call(bytes).records
  end

  let(:catalog) { bitmap_wire + brush_wire + escape_wire }
  let(:catalog_bytes) { native_wmf_bytes(catalog, capacity: 4096) }

  it "gives native-backed records the same view values as the Ruby parser and the Rust decoder" do
    reference = ruby_records(catalog_bytes)
    expect(Emf::Wmf::Parser).not_to receive(:call)
    native = native_records(catalog_bytes)

    expect(native.length).to eq(reference.length)
    rust.open(catalog_bytes) do |session|
      native.each_with_index do |record, index|
        expected = ruby_views(reference[index])

        expect(ruby_views(record)).to eq(expected), "native-backed record #{index} (#{format('0x%04X', record.type_id)})"
        expect(session.record_views(index)).to eq(expected), "Rust record #{index} (#{format('0x%04X', record.type_id)})"
      end
    end
  end

  it "covers every view kind with both present and absent results" do
    reference = ruby_records(catalog_bytes)
    views = reference.map { |record| ruby_views(record) }

    expect(views.flatten.map(&:class).uniq).to include(
      Emf::Wmf::Bitmap16::Image, Emf::Wmf::Dib::Image, Emf::Wmf::BitmapImage::Absent, Emf::Wmf::EscapeViews::Payload,
      Emf::Wmf::EscapeViews::CountedPayload, Emf::Wmf::EscapeViews::SpecialPassthrough2, Emf::Wmf::EmbeddedEmf::Segment, Symbol
    )
    expect(Emf::Wmf::EmbeddedEmf::Invalid.new(:x)).to be_a(Emf::Error)
    expect(views.count(&:empty?)).to be > 40
    expect(views.count { |entry| !entry.empty? }).to be > 120
    expect(reference.grep(Emf::Model::Wmf::Records::DibCreatePatternBrush).filter_map(&:target_dib).map { |dib| dib.colors.kind }.uniq)
      .to include(:rgb_quads, :palette_indices, :none, :rgb_triples)
  end

  it "assembles embedded EMF sequences identically in Ruby, native-backed records and Rust" do
    emf = "EMF-STREAM-" * 40
    sequences_for(emf).each do |label, escapes|
      bytes = native_wmf_bytes(escapes.map { |record| wire_escape(record) }, capacity: 4)
      expected = Emf::Wmf::EmbeddedEmf.sequences(ruby_records(bytes))
      native = Emf::Wmf::EmbeddedEmf.sequences(native_records(bytes))

      expect(native).to eq(expected), label
      rust.open(bytes) { |session| expect(session.embedded_sequences).to eq(expected), label }
    end
  end

  def sequences_for(emf)
    other = Emf::Model::Wmf::Records::Escape.new(escape_function: 0x0013, data: "ab".b)
    {
      "multi-segment" => embedded_escapes(emf, 100), "single segment" => embedded_escapes("tiny", 100),
      "bad checksum" => embedded_escapes(emf, 100).each { |escape| escape.data[12, 2] = "\1\0".b },
      "incomplete" => embedded_escapes(emf, 100).first(2),
      "extra after complete" => embedded_escapes("tiny", 100) + embedded_escapes("more", 100),
      "mixed with other escape" => embedded_escapes(emf, 100).first(1) + [other]
    }
  end
end
