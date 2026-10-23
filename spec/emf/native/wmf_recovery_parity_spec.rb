# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/wmf_recovery"

RSpec.describe "WMF recovered record shapes: Ruby and native parity" do
  include_context "with native library"
  extend WmfRecovery
  include WmfRecovery

  def parse_with(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    Emf.parse(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def summary(metafile)
    [metafile.records.map { |record| [record.class, record.type_id, record.offset, record.declared_size_words] },
     metafile.trailing, metafile.errors.map { |e| [e.class, e.message, e.offset, e.record_code, e.evidence.to_a] }]
  end

  def failure(backend, bytes)
    parse_with(backend, bytes)
    nil
  rescue Emf::Error => e
    [e.class, e.message, e.offset, e.record_code, e.evidence.to_a]
  end

  cases.each do |name, expected|
    it "gives identical records, errors and serialization for #{name}" do
      native = parse_with("native", expected[:bytes])
      ruby = parse_with("ruby", expected[:bytes])
      expect(native.records.map(&:type_id)).to eq(expected[:types])
      expect(native.errors.map { |error| error.evidence.check }).to eq([expected[:check]])
      expect(summary(native)).to eq(summary(ruby))
      expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
    end
  end

  rejected.each do |name, (bytes, message)|
    it "rejects #{name} with the same error on both backends" do
      ruby = failure("ruby", bytes)
      expect(ruby[1]).to match(message)
      expect(failure("native", bytes)).to eq(ruby)
    end
  end

  it "lists a checksum, a recovered EOF and a reference error in the same order on both backends" do
    bytes = stream([native_wmf_record(0x01F0, [5].pack("v")), eof_words(5)], objects: 1, placeable: true).tap do |file|
      file[20, 2] = [0xFFFF].pack("v")
    end
    native = parse_with("native", bytes)
    expect(native.errors.map do |error|
      error.evidence.check
    end).to eq(%i[placeable_checksum_mismatch object_reference_invalid eof_length_invalid])
    expect(summary(native)).to eq(summary(parse_with("ruby", bytes)))
  end
end
