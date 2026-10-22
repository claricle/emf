# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"

# Native `values` reads the record bytes the native parse located; it never
# builds a BinData wire for a record that has a value view.
RSpec.describe "Native WireAdapter#values source" do
  include_context "with native library"

  # CI sets only EMF_TEST_NATIVE_LIBRARY; the native backend loads EMF_NATIVE_LIBRARY.
  around do |example|
    previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", previous)
    example.run
  ensure
    ENV["EMF_NATIVE_LIBRARY"] = previous
  end

  let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("emf", "test-031.emf") }
  let(:records) do
    ENV["EMF_BACKEND"] = "native"
    Emf.parse(bytes).records
  ensure
    ENV.delete("EMF_BACKEND")
  end

  it "serves every value-view record from bytes without making its wire" do
    viewed = records.select { |record| record.instance_variable_get(:@wire_source)&.value_source }
    expect(viewed.size).to be > 70_000
    viewed.each { |record| expect(record.values).not_to be_nil }
    expect(viewed.map { |record| record.instance_variable_get(:@wire) }).to all(be_nil)
  end

  it "has a byte source for every record whose wire class has a value view" do
    sourceless = records.select do |record|
      source = record.instance_variable_get(:@wire_source)
      source && Emf::Emr::Binary::ValueView.for_class(source.wire_class) && source.value_source.nil?
    end
    expect(sourceless).to be_empty
  end
end
