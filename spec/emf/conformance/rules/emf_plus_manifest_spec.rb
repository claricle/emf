# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "EMF+ rule manifest" do
  path = File.expand_path("../../../../lib/emf/conformance/manifest/emf_plus.yml", __dir__)
  rows = YAML.safe_load_file(path)
  statuses = Emf::Conformance::Manifest::STATUSES
  # Registered by emf_plus.rb (chunk 1), whose manifest rows belong to that file's owner.
  chunk_one = %w[emfplus.record.reserved_type emfplus.record.stroke_fill_path emfplus.record.unknown_type
                 emfplus.header.placement emfplus.stream.framing]
  registered = Emf::Conformance::Registry.default.select { |rule| rule.formats == [:emf_plus] }.map(&:id)

  it "has a unique id on every row, a known status, and a reason on every row that is not implemented" do
    expect(rows.map { |row| row["id"] }.uniq.size).to eq(rows.size)
    expect(rows.map { |row| row["status"] }).to all(satisfy { |status| statuses.include?(status) })
    rows.reject { |row| row["status"] == "implemented" }.each do |row|
      expect(row["reason"]).to be_a(String), row["id"]
      expect(row["reason"]).not_to be_empty
    end
    expect(rows.select { |row| row["status"] == "implemented" }.map { |row| row["reason"] }).to all(be_nil)
  end

  it "lists exactly the implemented rows as registered rules, and every non-chunk-1 EMF+ rule has a row" do
    implemented = rows.select { |row| row["status"] == "implemented" }.map { |row| row["id"] }
    expect(implemented).to all(satisfy { |id| registered.include?(id) })
    expect(registered - chunk_one - implemented).to be_empty
  end

  it "cites a spec section on every row" do
    expect(rows.map { |row| row["citation"] }).to all(match(/\AMS-EMFPLUS \d+(\.\d+)+\z/))
  end

  it "keeps the 55th type, StrokeFillPath, as a blocked row" do
    expect(rows.find { |row| row["id"] == "emfplus.stroke_fill_path.fields" }).to include("status" => "blocked:model")
  end
end
