# frozen_string_literal: true

require "spec_helper"
require "emf/resource_budget"
require "emf/native/loader"
require_relative "../support/resource_contract"
require_relative "../support/native_library_context"
require_relative "../support/resource_budget_core_fixtures"

RSpec.describe Emf::ResourceBudget do
  include Emf::SpecSupport::ResourceContract

  it "accepts the inclusive header-only budget" do
    expect(described_class.check!(minimal_resource_emf, limits: { allocated_bytes: 88, work_units: 13, record_count: 1 })).to be(true)
  end

  it "reports the requested total before accepting an exceeded charge" do
    expect { described_class.check!(minimal_resource_emf, limits: { work_units: 12 }) }
      .to raise_error(Emf::ResourceLimitError) { |error| expect([error.resource, error.limit, error.actual]).to eq([:work_units, 12, 13]) }
  end

  it "checks input admission before format detection" do
    expect { described_class.check!("bad", limits: { input_bytes: 2 }) }
      .to raise_error(Emf::ResourceLimitError) { |error| expect(error.resource).to eq(:input_bytes) }
  end

  it "leaves malformed minimum header errors to the parser before budget charges" do
    bytes = minimal_resource_emf
    bytes[4, 4] = [87].pack("V")
    expect(described_class.check!(bytes, limits: { record_bytes: 0, work_units: 0, allocated_bytes: 0 })).to be(true)
  end

  it "charges a truncated extended header before returning control to the parser" do
    bytes = minimal_resource_emf
    bytes[4, 4] = [108].pack("V")
    expect { described_class.check!(bytes, limits: { record_bytes: 107 }) }
      .to raise_error(Emf::ResourceLimitError) { |error| expect(error.actual).to eq(108) }
    expect(described_class.check!(bytes, limits: { allocated_bytes: 0, work_units: 8 })).to be(true)
  end
end

RSpec.describe Emf::ResourceBudget, "native charge parity" do
  include Emf::SpecSupport::ResourceContract
  include Emf::SpecSupport::ResourceBudgetCoreFixtures

  include_context "with native library"

  let(:loader) { Emf::Native::Loader.new(library) }
  let(:defaults) { described_class::DEFAULT_LIMITS }

  %i[record_bytes record_count allocated_bytes work_units].each do |resource|
    it "matches every native #{resource} charge in core fixtures" do
      core_budget_fixtures.each do |name, bytes|
        ceiling = 0
        loop do
          limits = defaults.merge(resource => ceiling)
          native = budget_outcome { native_resource_parse(loader, bytes, limits.values) }
          ruby = budget_outcome { described_class.check!(bytes, limits: limits) }
          expect(ruby).to eq(native), "#{name} #{resource} limit=#{ceiling}"
          break if native == :accepted

          # Each next rejected total discovers the native charge sequence, then
          # verifies its inclusive boundary before advancing to the next charge.
          ceiling = native.last
        end
      end
    end
  end
end
