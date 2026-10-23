# frozen_string_literal: true

require "spec_helper"
require "emf/resource_budget"
require "emf/native/loader"
require_relative "../support/resource_contract"
require_relative "../support/resource_budget_fixtures"
require_relative "../support/native_library_context"

RSpec.describe Emf::ResourceBudget, "delegated native charge parity" do
  include Emf::SpecSupport::ResourceContract
  include Emf::SpecSupport::ResourceBudgetFixtures

  include_context "with native library"

  let(:loader) { Emf::Native::Loader.new(library) }

  def native_outcome(bytes, resource, limit)
    limits = described_class::DEFAULT_LIMITS.merge(resource => limit)
    native_resource_parse(loader, bytes, limits.values_at(:input_bytes, :record_bytes, :record_count, :allocated_bytes, :work_units))
  rescue Emf::ResourceLimitError => e
    [e.resource, e.limit, e.actual]
  end

  def ruby_outcome(bytes, resource, limit)
    described_class.check!(bytes, limits: { resource => limit })
  rescue Emf::ResourceLimitError => e
    [e.resource, e.limit, e.actual]
  end

  # Visit every native charge boundary: a later charge can fail even when an
  # earlier charge fits exactly. This also checks malformed recovery precedence.
  def expect_charge_parity(bytes, resource)
    limit = 0
    32.times do
      native = native_outcome(bytes, resource, limit)
      expect(ruby_outcome(bytes, resource, limit)).to eq(native), "#{resource} ceiling #{limit}"
      return limit if native == true

      actual = native.fetch(2)
      expect(actual).to be > limit
      below = actual - 1
      expected = [resource, below, actual]
      expect(native_outcome(bytes, resource, below)).to eq(expected)
      expect(ruby_outcome(bytes, resource, below)).to eq(expected)
      limit = actual
    end
    raise "native charge sequence did not converge"
  end

  {
    "bitmap" => -> { budget_bitmap },
    "PolyText A" => -> { budget_poly_text },
    "PolyText W" => -> { budget_poly_text(wide: true) },
    "gradient rectangles" => -> { budget_gradient },
    "gradient triangles" => -> { budget_gradient(mode: 2) }
  }.each do |name, fixture|
    it "preserves accepted #{name} bytes through Ruby parsing and serialization" do
      bytes = instance_exec(&fixture).freeze
      expect(described_class.check!(bytes)).to be(true)
      with_resource_backend("ruby") do
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
      end
    end
  end

  {
    "bitmap buffers" => -> { budget_bitmap },
    "PolyText A text, dx and padding" => -> { budget_poly_text },
    "PolyText W text, dx and padding" => -> { budget_poly_text(wide: true) },
    "gradient rectangles without padding" => -> { budget_gradient },
    "gradient triangles" => -> { budget_gradient(mode: 2) },
    "bitmap invalid range before buffer charges" => -> { budget_bitmap(malformed: :range) },
    "bitmap overlapping buffers before buffer charges" => -> { budget_bitmap(malformed: :overlap) },
    "PolyText A invalid range after descriptor charges" => -> { budget_poly_text(malformed: :range) },
    "PolyText W invalid range after descriptor charges" => -> { budget_poly_text(wide: true, malformed: :range) },
    "PolyText A overlap after text and sorting charges" => -> { budget_poly_text(malformed: :overlap) },
    "PolyText W overlap after text and sorting charges" => -> { budget_poly_text(wide: true, malformed: :overlap) },
    "PolyText malformed table before descriptor charges" => -> { budget_poly_text(malformed: :table) },
    "gradient invalid range before vertex work" => -> { budget_gradient(malformed: :range) },
    "gradient invalid index after vertex work" => -> { budget_gradient(malformed: :index) }
  }.each do |name, fixture|
    it "matches every inclusive allocation and work boundary for #{name}" do
      bytes = instance_exec(&fixture).freeze
      original = bytes.dup
      expect_charge_parity(bytes, :allocated_bytes)
      expect_charge_parity(bytes, :work_units)
      expect(described_class.check!(bytes)).to be(true)
      expect(bytes).to eq(original)
    end
  end
end
