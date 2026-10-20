# frozen_string_literal: true

require "spec_helper"
load File.expand_path("../../script/record_coverage", __dir__)

RSpec.describe RecordCoverage do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:plan) { File.read(File.join(root, "TODO.plan/11-record-coverage.md")) }
  let(:registry) { File.read(File.join(root, "lib/emf/emr/binary/records.rb")) }
  let(:codes) { File.read(File.join(root, "lib/emf/emr/binary/type_codes.rb")) }

  it "matches every autoloaded class, constant and wire source, including Raw" do
    expect(described_class.new(root).errors).to eq([])
  end

  it "rejects the historical SetDIBitsToDevice spelling without losing other rows" do
    altered = plan.sub("`SetDibitsToDevice`", "`SetDIBitsToDevice`")
    expect(altered).not_to eq(plan)
    expect(described_class.new(root, plan: altered).errors).to contain_exactly(
      "missing inventory class SetDibitsToDevice", "unknown inventory class SetDIBitsToDevice"
    )
  end

  it "rejects missing, extra and duplicate inventory rows" do
    row = plan.lines.find { |line| line.start_with?("| `Eof`") }
    expect(described_class.new(root, plan: plan.sub(row, "")).errors).to eq(["missing inventory class Eof"])
    expect(described_class.new(root, plan: plan + row).errors).to eq(["duplicate inventory class Eof"])
    expect(described_class.new(root, plan: plan + row.sub("`Eof`", "`Invented`")).errors).to eq(["unknown inventory class Invented"])
  end

  it "rejects constant and source-link drift independently" do
    expect(described_class.new(root, plan: plan.sub("`EOF`", "`HEADER`")).errors).to eq(["wrong type-code constant for Eof: HEADER"])
    altered = plan.sub("../lib/emf/emr/binary/records/eof.rb", "../lib/missing.rb")
    expect(described_class.new(root, plan: altered).errors).to eq(["wrong source path for Eof: ../lib/missing.rb"])
  end

  it "detects numeric collisions before a Ruby registry hash can overwrite an entry" do
    # HEADER is not a registered record, so collide with POLYBEZIER (2).
    altered = codes.sub(/EOF\s*=\s*14/, "EOF = 2")
    expect(altered).not_to eq(codes)
    expect(described_class.new(root, type_codes: altered).errors).to eq(["duplicate numeric type code 2"])
  end

  it "rejects a newly registered class absent from the inventory" do
    altered = "#{registry}\nautoload :Added, \"emf/emr/binary/records/added\"\nBinary::TypeCodes::HEADER => :Added,\n"
    expect(described_class.new(root, registry: altered).errors).to eq(["missing inventory class Added"])
  end

  it "does not turn bounded progress into a semantic completion assertion" do
    expect(described_class.new(root, plan: plan.gsub("In progress", "Not started")).errors).to eq([])
  end

  it "rejects undefined constants and unregistered autoloads" do
    altered = codes.sub(/EOF\s*=\s*14/, "")
    expect(described_class.new(root, type_codes: altered).errors).to eq(["undefined type-code constant EOF"])
    altered = registry.sub(/\s*Binary::TypeCodes::EOF\s*=>\s*:Eof,/, "")
    expect(described_class.new(root, registry: altered).errors).to contain_exactly(
      "autoload without registration Eof", "wrong type-code constant for Eof: EOF"
    )
  end

  it "fails closed when a registry declaration no longer matches the literal extractor" do
    altered = registry.sub('autoload :Eof, "emf/emr/binary/records/eof"', 'autoload(:Eof, "emf/emr/binary/records/eof")')
    expect(altered).not_to eq(registry)
    expect(described_class.new(root, registry: altered).errors).to include("unsupported registry declaration syntax")
  end
end
