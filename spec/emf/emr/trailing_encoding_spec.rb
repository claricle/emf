# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Parser, "trailing bytes" do
  it "are binary, as the native backend returns them" do
    bytes = File.binread("spec/fixtures/emf/test-000.emf")
    expect(described_class.call(bytes).trailing.encoding).to eq(Encoding::BINARY)
    expect(described_class.call(bytes + "\n\xFF".b).trailing).to eq("\n\xFF".b)
  end
end
