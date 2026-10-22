# frozen_string_literal: true

require "spec_helper"
require_relative "support/record_inventories"

# The coverage oracle for issue #37 AC1 ("per record type"): every record type of the three
# inventories must appear in at least one manifest row, by name or by numeric code. A row with
# `record_types: []` is a generic rule and does not count toward any type. A type counts as covered only
# by an `implemented` row or by a `blocked:model` / `not_checkable` row (with its reason). A `deferred`
# row ("readable, rule not written") is a to-do and does not count; it may sit beside a covering row.
RSpec.describe Emf::Conformance::Manifest do
  let(:covering) { %w[implemented blocked:model not_checkable] }
  let(:rows) { described_class.rows }

  def covered(format, inventory)
    named = rows.select { |row| row.format == format && covering.include?(row.status) }.flat_map(&:record_types)
    inventory.reject { |name, code| named.include?(name) || named.include?(code) }.keys
  end

  def inventory(format) = Emf::SpecSupport::RecordInventories.public_send(format)

  it "pins the inventory sizes so a shrinking inventory cannot hide a gap" do
    expect([inventory(:emf).size, inventory(:emf_plus).size, inventory(:wmf).size]).to eq([119, 55, 70])
    expect(inventory(:emf_plus).values.sort).to eq((0x4001..0x403A).to_a - (0x4005..0x4007).to_a)
  end

  it "has a row for every EMF record type" do
    expect(covered("emf", inventory(:emf))).to eq([])
  end

  it "has a row for every EMF+ record type" do
    expect(covered("emf_plus", inventory(:emf_plus))).to eq([])
  end

  it "has a row for every WMF RecordType entry" do
    expect(covered("wmf", inventory(:wmf))).to eq([])
  end

  def row(status, reason: nil)
    described_class::Row.new(id: "x", format: "emf", record_types: ["EMR_HEADER"], citation: "c", status: status, reason: reason)
  end

  it "does not count a deferred row as covering a type" do
    allow(described_class).to receive(:rows).and_return([row("deferred", reason: "not written")])
    expect(covered("emf", inventory(:emf))).to include("EMR_HEADER")
  end

  %w[implemented not_checkable blocked:model].each do |status|
    it "counts a #{status} row as covering a type, even beside a deferred row" do
      allow(described_class).to receive(:rows).and_return([row("deferred", reason: "not written"), row(status, reason: "r")])
      expect(covered("emf", inventory(:emf))).not_to include("EMR_HEADER")
    end
  end

  it "does not count a generic row (record_types: []) as covering a type" do
    generic = described_class::Row.new(id: "x", format: "emf", record_types: [], citation: "c", status: "implemented")
    allow(described_class).to receive(:rows).and_return([generic])
    expect(covered("emf", inventory(:emf)).size).to eq(119)
  end
end
