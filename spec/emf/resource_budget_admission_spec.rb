# frozen_string_literal: true

require "spec_helper"
require "emf/resource_limits"
require_relative "../support/resource_contract"
require_relative "../support/native_library_context"

RSpec.shared_examples "public budget admission" do |backend|
  include Emf::SpecSupport::ResourceContract

  around { |example| with_resource_backend(backend) { example.run } }

  it "admits inclusive budgets through the selected parser" do
    stub_const("Emf::ResourceBudget::DEFAULT_LIMITS",
               Emf::ResourceBudget::DEFAULT_LIMITS.merge(allocated_bytes: 88, work_units: 13))
    expect(Emf.parse(minimal_resource_emf).format).to eq(:emf)
  end

  { allocated_bytes: [87, 88], work_units: [12, 13] }.each do |resource, (limit, actual)|
    it "enforces #{resource} through the public parse API" do
      stub_const("Emf::ResourceBudget::DEFAULT_LIMITS", Emf::ResourceBudget::DEFAULT_LIMITS.merge(resource => limit))
      expect { Emf.parse(minimal_resource_emf) }.to raise_error(Emf::ResourceLimitError) { |error|
        expect([error.resource, error.limit, error.actual]).to eq([resource, limit, actual])
      }
    end
  end

  it "preserves native work-before-allocation refusal order" do
    stub_const("Emf::ResourceBudget::DEFAULT_LIMITS",
               Emf::ResourceBudget::DEFAULT_LIMITS.merge(allocated_bytes: 0, work_units: 0))
    expect { Emf.parse(minimal_resource_emf) }.to raise_error(Emf::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:work_units, 0, 7])
    }
  end

  it "checks a current record array before the next record's count" do
    stub_const("Emf::Emr::Parser::MAX_SANE_ARRAY_LENGTH", 8)
    stub_const("Emf::ResourceLimits::EmfRecords::MAX_RECORDS", 2)
    bytes = minimal_resource_emf + resource_array_record(2, 9) + resource_record(33, 8)
    expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq([:array_elements, 8, 9])
    }
  end
end

RSpec.describe "Ruby public budget admission" do
  include_examples "public budget admission", "ruby"
end

RSpec.describe "Native public budget admission" do
  include_context "with native library"

  around do |example|
    original = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    original ? ENV["EMF_NATIVE_LIBRARY"] = original : ENV.delete("EMF_NATIVE_LIBRARY")
  end

  before { expect(Emf::Emr::Parser).not_to receive(:call) }

  %w[native auto].each do |backend|
    context "with #{backend} selection" do
      include_examples "public budget admission", backend
    end
  end
end
