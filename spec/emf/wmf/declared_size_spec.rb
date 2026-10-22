# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_mutation"
require_relative "../../support/native_library_context"

RSpec.describe "WMF declared record size" do
  include_context "with native library"

  let(:rejected_seeds) { %w[file-size header-size max-record missing-eof negative-text placeable-checksum bitmap-short zero-record] }

  def sizes_through(backend, bytes)
    records_through(backend, bytes).map { |record| [record.type_id, record.declared_size_words, record.declared_size_bytes] }
  end

  def records_through(backend, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library if backend == "native"
    Emf.parse(bytes).records
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| previous[key] ? ENV[key] = previous[key] : ENV.delete(key) }
  end

  def rdsize_on_wire(bytes, offsets)
    offsets.map { |offset| bytes.unpack1("V", offset: offset) }
  end

  it "reports each record's rdSize in words and bytes as declared in the file, equally on both backends" do
    accepted = WmfMutation.seeds.reject { |name, _bytes| rejected_seeds.any? { |prefix| name.start_with?(prefix) } }
    expect(accepted.length).to eq(10)
    records = 0
    accepted.each do |name, bytes|
      ruby = sizes_through("ruby", bytes)
      expect(sizes_through("native", bytes)).to eq(ruby), name
      expect(ruby.map(&:last)).to eq(ruby.map { |_id, words, _bytes| words * 2 }), name
      expect(ruby.map { |_id, words, _bytes| words }).to all(be >= 3), name
      records += ruby.length
    end
    expect(records).to be > 20
  end

  it "matches the rdSize field written at each record offset" do
    bytes = File.binread("spec/fixtures/wmf/placeable-line.wmf")
    %w[ruby native].each do |backend|
      offsets = records_through(backend, bytes).map(&:offset)
      expect(records_through(backend, bytes).map(&:declared_size_words)).to eq(rdsize_on_wire(bytes, offsets)), backend
    end
  end

  it "is nil for a record built in memory" do
    record = Emf::Model::Wmf::Records::MoveTo.new(x: 1, y: 2)
    expect([record.declared_size_words, record.declared_size_bytes]).to eq([nil, nil])
  end
end
