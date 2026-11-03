# frozen_string_literal: true

require "spec_helper"
require "psych"
require "tempfile"

RSpec.describe Emf::Conformance::Manifest do
  # Loaded per example, not at file load: an early yeptris load breaks a
  # later `require "leptris"` native layer on Linux Ruby 3.3/3.4.
  before { require "yeptris" }

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

  ["- id: :foo", "- record_types:\n  - :foo", "- reason:\n    nested: :foo", "- reason:\n    :foo: value"].each do |source|
    it "rejects implicit symbols in #{source}" do
      expect { Psych.safe_load(source) }.to raise_error(Psych::DisallowedClass)
      expect { load_manifest(source) }.to raise_error(Yeptris::Psych::DisallowedClass)
    end
  end

  ["0b11", "-0b11", "+0b1_1", "0b1,1", '"0b11"', "'0b11'", "!!str 0b11", "0b12"].each do |value|
    it "matches Psych for binary-looking scalar #{value}" do
      source = "- id: #{value}\n  record_types:\n  - #{value}\n  reason:\n    #{value}: #{value}\n"
      expected = Psych.safe_load(source).first.transform_keys(&:to_sym)

      expect(load_manifest(source).first.to_h.slice(*expected.keys)).to eq(expected)
    end
  end

  it "preserves quoted symbol-looking strings" do
    expect(load_manifest('- id: ":foo"').first.id).to eq(":foo")
  end

  it "uses the last value for duplicate mapping keys" do
    source = "- id: a\n  id: b\n"

    expect(load_manifest(source).first.id).to eq(Psych.safe_load(source).first.fetch("id"))
  end

  it "uses the last value for nested duplicate mapping keys" do
    source = "- reason:\n    code: 0b10\n    code: 0b11\n"

    expect(load_manifest(source).first.reason).to eq(Psych.safe_load(source).first.fetch("reason"))
  end

  ["!custom value", "2001-01-01"].each do |value|
    it "still rejects an unsafe duplicate value #{value} before it is overwritten" do
      source = "- id: #{value}\n  id: safe\n"

      expect { load_manifest(source) }.to raise_error(Yeptris::Psych::DisallowedClass)
    end
  end

  it "preserves mapping merges while correcting binary scalars" do
    source = "- <<: [{id: 0b11}, {id: 0b10, citation: test}]\n"
    expected = Psych.safe_load(source).first.transform_keys(&:to_sym)

    expect(load_manifest(source).first.to_h.slice(*expected.keys)).to eq(expected)
  end

  ["!custom value", "!ruby/object:Object {}", "2001-01-01"].each do |value|
    it "rejects disallowed values such as #{value}" do
      expect { load_manifest("- id: #{value}\n") }.to raise_error(Yeptris::Psych::DisallowedClass)
    end
  end

  it "does not load yeptris until a manifest is read" do
    lib = File.expand_path("../../../lib", __dir__)
    script = 'require "emf"; Emf::Conformance::Manifest; exit(defined?(Yeptris) ? 1 : 0)'

    expect(system(RbConfig.ruby, "-I", lib, "-e", script, out: File::NULL, err: File::NULL)).to be(true)
  end
end
