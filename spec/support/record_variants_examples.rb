# frozen_string_literal: true

require_relative "record_variants_runner"
require_relative "native_library_context"

# Shared examples: every variant of the named registry classes, on both backends.
RSpec.shared_examples "record variants" do |names|
  include_context "with native library"

  backends = %w[ruby native].freeze

  def observe_pair(bytes)
    %w[ruby native].to_h { |backend| [backend, RecordVariants::Runner.observe(bytes, backend, library)] }
  end

  def expect_fields(observed, variant)
    wire = observed.wire
    variant.fields.each do |field|
      next unless field.path

      actual = RecordVariants::Runner.comparable(RecordVariants::Runner.value_of(wire, field.path), field.value)
      expect(actual).to eq(field.value), "#{variant.record} #{variant.name} #{field.path}: #{actual.inspect}"
    end
  end

  def expect_variant(observed, variant, backend, expected_class)
    expect(observed.parsed_lazily).to be(backend == "native"), "#{backend} did not take its own parse path"
    return unless variant.kind == :valid

    expect(observed.wire).to be_a(expected_class), "#{backend}: #{observed.wire.class}"
    expect(observed.errors).to be_empty, "#{backend}: #{observed.errors.map(&:message)}"
    record = RecordVariants.record_bytes(variant)
    expect(observed.metafile.records.first.to_binary_s).to eq(record)
    expect(record.start_with?(observed.wire_bytes)).to be(true), "#{backend} wire bytes are not the record prefix"
    expect_fields(observed, variant)
  end

  def expect_agreement(pair, bytes)
    expect(BackendParity.differences(pair["ruby"].section, pair["native"].section)).to be_empty
    pair.each do |backend, observed|
      expect(observed.serialized).to eq(bytes), "#{backend} serialization differs from input"
      again = RecordVariants::Runner.reparse(observed, backend, library)
      expect(BackendParity.differences(observed.section, again)).to be_empty, "#{backend} reparse differs"
    end
  end

  names.each do |name|
    entry = RecordVariants::REGISTRY.fetch(name)
    klass = Emf::Emr::Binary::Records.const_get(name)

    describe name do
      entry.variants.each do |variant|
        it "#{variant.kind} #{variant.name}: Ruby/native fields, diagnostics and exact bytes" do
          pending variant.pending if variant.pending
          bytes = RecordVariants.source(variant)
          pair = observe_pair(bytes)
          expected_class = variant.raw_class ? Emf::Emr::Binary::Records::Raw : klass
          backends.each { |backend| expect_variant(pair.fetch(backend), variant, backend, expected_class) }
          expect(pair["native"].wire.class).to eq(pair["ruby"].wire.class)
          expect(BackendParity.differences(pair["ruby"].section, pair["native"].section)).to be_empty
          expect_agreement(pair, bytes)
          NativeCorpusParity.observable!(pair["native"].section["records"]) if variant.kind == :valid
        end
      end

      RecordVariants.derived(entry).each do |label, record|
        it "derived #{label}: Ruby/native diagnostics and exact bytes" do
          pending entry.derived_pending[label] if entry.derived_pending[label]
          bytes = "#{RecordVariants::HEADER_BYTES.call}#{record}#{RecordVariants::EOF_RECORD}".b
          pair = observe_pair(bytes)
          expect(pair["native"].wire.class).to eq(pair["ruby"].wire.class)
          expect_agreement(pair, bytes)
        end
      end
    end
  end
end
