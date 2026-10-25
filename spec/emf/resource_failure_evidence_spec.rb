# frozen_string_literal: true

require "spec_helper"
require_relative "../support/resource_contract"
require_relative "../support/native_library_context"
require_relative "../support/wmf_rejection_cases"

RSpec.shared_examples "resource refusal evidence" do |backend|
  include Emf::SpecSupport::ResourceContract

  around { |example| with_resource_backend(backend) { example.run } }

  before { expect(Emf.backend).to eq(backend == "ruby" ? :ruby : :native) }

  it "retains EMF input-size evidence alongside structured resource metadata" do
    bytes = minimal_resource_emf
    stub_const("Emf::Emr::Parser::MAX_INPUT_BYTES", bytes.bytesize - 1)

    expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, bytes.bytesize - 1, bytes.bytesize])
      expect(error.evidence&.to_h).to eq(check: :emf_input_too_large, offset: 0,
                                         declared: bytes.bytesize - 1, actual: bytes.bytesize)
    }
  end

  [false, true].each do |placeable|
    context "with #{placeable ? 'placeable' : 'standard'} WMF" do
      let(:prefix) { placeable ? WmfRejectionCases.placeable : "".b }
      let(:bytes) { prefix + WmfRejectionCases.wmf(([WmfRejectionCases.rec(0x1E)] * 2) + [WmfRejectionCases.eof]) }

      it "retains input-size evidence alongside structured resource metadata" do
        stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize - 1)

        expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
          expect([error.resource, error.limit, error.actual]).to eq([:input_bytes, bytes.bytesize - 1, bytes.bytesize])
          expect(error.evidence&.to_h).to eq(check: :input_too_large, offset: 0,
                                             declared: bytes.bytesize - 1, actual: bytes.bytesize)
        }
      end

      it "retains the first refused record's offset and historical count evidence" do
        stub_const("Emf::Wmf::Binary::MAX_RECORDS", 2)

        expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
          expect([error.resource, error.limit, error.actual]).to eq([:record_count, 2, 3])
          expect(error.evidence&.to_h).to eq(check: :record_limit_exceeded, offset: prefix.bytesize + 30,
                                             declared: 2, actual: 2)
        }
      end
    end
  end
end

RSpec.describe "Ruby resource refusal evidence" do
  include_examples "resource refusal evidence", "ruby"
end

RSpec.describe "Native resource refusal evidence" do
  include_context "with native library"

  around do |example|
    previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    ENV["EMF_NATIVE_LIBRARY"] = previous
  end

  %w[native auto].each do |backend|
    context "with #{backend} selection" do
      include_examples "resource refusal evidence", backend
    end
  end
end
