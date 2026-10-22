# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "emf_state_path.yml manifest" do
  rows = YAML.safe_load_file(File.expand_path("../../../lib/emf/conformance/manifest/emf_state_path.yml", __dir__))
  mine = /\Aemf\.(state|transform|path|clip|dc)\./
  implemented = rows.select { |row| row["status"] == "implemented" }

  it "has a row for every registered state, transform, path, clip and DC rule and none for a missing one" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(mine)
    expect(implemented.map { |row| row["id"] }).to match_array(registered)
  end

  it "cites each implemented row the way its rule does" do
    implemented.each do |row|
      expect(row["citation"]).to eq(Emf::Conformance::Registry.default[row["id"]].citation), row["id"]
    end
  end

  it "gives every row that is not implemented a reason, and no implemented row one" do
    rows.each do |row|
      expect(row["status"]).to match(/\A(implemented|deferred|blocked:model|not_checkable)\z/)
      expect(row["reason"].to_s.empty?).to eq(row["status"] == "implemented"), row["id"]
    end
  end

  it "has unique ids" do
    expect(rows.map { |row| row["id"] }.uniq.size).to eq(rows.size)
  end

  it "names only record types the library defines" do
    names = Emf::Emr::Binary::TypeCodes.constants.map { |name| "EMR_#{name}" }
    expect(rows.flat_map { |row| row["record_types"] } - names).to be_empty
  end
end
