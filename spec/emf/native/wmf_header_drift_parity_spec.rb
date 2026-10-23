# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/wmf_header_drift"

RSpec.describe "WMF header Size and MaxRecord drift: Ruby and native parity" do
  include_context "with native library"
  include WmfHeaderDrift

  def parse_with(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    Emf.parse(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def summary(metafile)
    header = metafile.header
    placeable = header.placeable
    [[header.type, header.version, header.size_words, header.number_of_objects, header.max_record_words, header.number_of_members,
      placeable&.instance_variables&.map { |name| placeable.instance_variable_get(name) }],
     metafile.records.map { |record| [record.class, record.type_id, record.offset, record.declared_size_words] },
     metafile.trailing, metafile.errors.map { |e| [e.class, e.message, e.offset, e.record_code, e.evidence.to_a] }]
  end

  [false, true].each do |placeable|
    WmfHeaderDrift::CASES.each do |name, (offset, value)|
      it "gives identical models, records and errors for #{name}#{' (placeable)' if placeable}" do
        bytes = drifted(pristine(placeable: placeable, trailing: "tl".b), offset, value, placeable: placeable)
        native = parse_with("native", bytes)
        ruby = parse_with("ruby", bytes)
        expect(summary(native)).to eq(summary(ruby))
        expect(native.errors.size).to eq(1)
        expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      end
    end
  end

  it "rejects the same truncated input, with the same error, on both backends" do
    bytes = drifted(pristine, 6, 0xFFFF_FFFF).byteslice(0, 40)
    errors = %w[ruby native].map do |backend|
      parse_with(backend, bytes)
      nil
    rescue Emf::Error => e
      [e.class, e.message, e.offset, e.evidence.to_a]
    end
    expect(errors.first).to include(Emf::ParseError, "WMF invalid record length 5 at offset 32")
    expect(errors.last).to eq(errors.first)
  end
end
