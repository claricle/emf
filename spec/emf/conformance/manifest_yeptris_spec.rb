# frozen_string_literal: true

require "spec_helper"
require "psych"
require "tempfile"

RSpec.describe Emf::Conformance::Manifest do
  paths = Dir[File.join(described_class::DIR, "*.yml")]

  paths.each do |path|
    it "parses #{File.basename(path)} identically with yeptris and Psych" do
      expected = Psych.safe_load_file(path, permitted_classes: [], aliases: false)
      actual = Yeptris::Psych.safe_load_file(path, permitted_classes: [], aliases: false)

      expect(actual).to eq(expected)
    end
  end

  it "returns every Psych-derived row in file-name and file order" do
    expect(paths).not_to be_empty
    expected = paths.flat_map do |path|
      Psych.safe_load_file(path).map do |entry|
        described_class::Row.new(**entry.transform_keys(&:to_sym), source: File.basename(path))
      end
    end

    rows = described_class.rows
    expect(rows).to eq(expected)
    expect(rows).to be_frozen
    expect(rows).to all(be_frozen)
  end

  def load_manifest(source)
    Tempfile.create(["manifest", ".yml"]) do |file|
      file.write(source)
      file.flush
      described_class.load_file(file.path)
    end
  end

  it "preserves nulls, integer codes, and colon-containing strings" do
    rows = load_manifest(<<~YAML)
      - id: scalar.test
        format: wmf
        record_types: [258, 0x0102, EMR_HEADER]
        citation: "001"
        status: blocked:model
        reason: null
    YAML

    expect(rows.first.to_h.except(:source)).to eq(
      id: "scalar.test", format: "wmf", record_types: [258, 258, "EMR_HEADER"],
      citation: "001", status: "blocked:model", reason: nil
    )
  end

  it "rejects aliases" do
    expect { load_manifest("- &row {id: example}\n- *row\n") }.to raise_error(Yeptris::Psych::AliasesError)
  end

  ["!custom value", "!ruby/object:Object {}", "2001-01-01"].each do |value|
    it "rejects disallowed values such as #{value}" do
      expect { load_manifest("- id: #{value}\n") }.to raise_error(Yeptris::Psych::DisallowedClass)
    end
  end
end
