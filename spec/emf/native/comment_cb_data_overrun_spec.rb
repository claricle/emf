# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/header_variant_wire"

RSpec.describe "EMR_COMMENT whose cbData claims more bytes than the record holds" do
  include_context "with native library"

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  let(:wire) { HeaderVariantWire }
  let(:backends) { %w[ruby native] }

  def document(comment)
    wire.header(108) + comment + wire::EOF_RECORD
  end

  def parse_with(backend, bytes)
    ENV["EMF_BACKEND"] = backend
    Emf.parse(bytes)
  end

  # nSize 12 leaves no room for data, but cbData claims 0x488CEB25 bytes.
  let(:empty_body) { [70, 12, 0x488CEB25].pack("V3") }
  # Four data bytes present that are not the EMF+ signature.
  let(:short_body) { [70, 16, 0x488CEB25].pack("V3") + "EM\0\0".b }

  %w[ruby native].each do |backend|
    it "parses an overrunning comment with no data on #{backend} without extracting EMF+" do
      metafile = parse_with(backend, document(empty_body))

      expect(metafile.emf_plus).to be_nil
      expect(Emf.serialize(metafile)).to eq(document(empty_body))
    end

    it "parses an overrunning comment whose data is not EMF+ on #{backend}" do
      metafile = parse_with(backend, document(short_body))

      expect(metafile.emf_plus).to be_nil
      expect(Emf.serialize(metafile)).to eq(document(short_body))
    end
  end

  it "gives the same records and errors on both backends" do
    [empty_body, short_body].each do |body|
      ruby, native = backends.map { |backend| parse_with(backend, document(body)) }

      expect(native.records.map(&:type_id)).to eq(ruby.records.map(&:type_id))
      expect(native.errors.map { |error| [error.class, error.offset] })
        .to eq(ruby.errors.map { |error| [error.class, error.offset] })
    end
  end
end
