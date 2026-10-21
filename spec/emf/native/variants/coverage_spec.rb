# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_state"
require_relative "../../../support/record_variants_poly"
require_relative "../../../support/record_variants_text"
require_relative "../../../support/record_variants_bitmap"
require_relative "../../../support/record_variants_region"
require_relative "../../../support/record_variants_objects"
require_relative "../../../support/record_variants_opaque"
require_relative "../../../support/record_variants_control"

RSpec.describe "Native record variant registry coverage" do
  let(:records) { Emf::Emr::Binary::Records }
  let(:registry_names) do
    records.constants.select { |name| records.const_get(name).is_a?(Class) }.map(&:to_s)
  end
  let(:catalogued) { RecordVariants::CATALOGS.values.flatten }

  it "declares variants for exactly the 119 registry classes" do
    expect(registry_names.size).to eq(119)
    expect(RecordVariants::REGISTRY.keys).to match_array(registry_names)
  end

  it "declares each registry class in exactly one catalog" do
    expect(catalogued).to match_array(registry_names)
    expect(catalogued).to eq(catalogued.uniq)
  end

  it "keys each class by the type code the registry dispatches on" do
    mismatches = RecordVariants::REGISTRY.reject do |name, entry|
      name == "Raw" || records::TYPE_TO_NAME[entry.type]&.to_s == name
    end
    expect(mismatches.keys).to be_empty
  end

  it "keeps Raw outside every registered type code" do
    codes = RecordVariants::REGISTRY.fetch("Raw").variants.map(&:type)
    expect(codes & records::TYPE_TO_NAME.keys).to be_empty
  end

  it "gives every class at least one valid variant" do
    bare = RecordVariants::REGISTRY.reject { |_, entry| entry.variants.any? { |variant| variant.kind == :valid } }
    expect(bare.keys).to be_empty
  end
end
