# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Emf::Conformance::Manifest do
  let(:rows) { described_class.rows }
  let(:registered) { Emf::Conformance::Registry.default.map(&:id) }
  let(:implemented) { rows.select(&:implemented?) }
  let(:unparseable_row_formats) { %w[emf wmf] }

  it "finds at least one family file, and every file is a well-formed list of rows" do
    expect(Dir[File.join(described_class::DIR, "*.yml")]).not_to be_empty
    expect(rows.flat_map { |row| described_class.problems(row).map { |p| "#{row.source} #{row.id}: #{p}" } }).to eq([])
  end

  it "has exactly one implemented row for every registered rule" do
    counts = implemented.map(&:id).tally
    expect(registered.reject { |id| counts[id] == 1 }).to eq([])
  end

  it "has a registered rule behind every implemented row" do
    expect(implemented.map(&:id) - registered).to eq([])
  end

  it "keeps a blocked or not_checkable row's id out of the registry, so a rule that lands flips its row" do
    expect(rows.reject(&:implemented?).map(&:id) & registered).to eq([])
  end

  it "gives every row that is not implemented a reason" do
    missing = rows.reject(&:implemented?).select { |row| row.reason.to_s.strip.empty? }
    expect(missing.map(&:id)).to eq([])
  end

  it "has unique ids across all files" do
    duplicated = rows.group_by(&:id).select { |_, group| group.size > 1 }
    expect(duplicated.transform_values { |group| group.map(&:source) }).to eq({})
  end

  it "agrees with the registry on the format of every implemented row" do
    mismatched = implemented.reject do |row|
      rule = Emf::Conformance::Registry.default[row.id]
      rule.formats.include?(row.format.to_sym) || (unparseable_row_formats.include?(row.format) && rule.formats.include?(:unparseable))
    end
    expect(mismatched.map(&:id)).to eq([])
  end

  describe "loader" do
    def write(dir, name, text) = File.write(File.join(dir, name), text)

    let(:dir) { Dir.mktmpdir }
    let(:good) do
      "- {id: a.b, format: emf, record_types: [EMR_EOF], citation: 'MS-EMF 1', status: implemented, reason: null}\n"
    end

    it "reads rows from every file in name order and remembers the source" do
      write(dir, "z.yml", good.sub("a.b", "z.z"))
      write(dir, "a.yml", good)
      expect(described_class.rows(dir).map { |r| [r.source, r.id] }).to eq([%w[a.yml a.b], %w[z.yml z.z]])
    end

    it "flags a non-implemented row without a reason, a bad status and a bad format" do
      write(dir, "x.yml", "- {id: x.a, format: svg, record_types: [], citation: c, status: planned, reason: ' '}\n" \
                          "- {id: x.b, format: wmf, record_types: [], citation: c, status: blocked:model}\n" \
                          "- {id: x.c, format: wmf, record_types: [], citation: c, status: implemented, reason: why}\n")
      problems = described_class.rows(dir).map { |row| described_class.problems(row) }
      expect(problems[0]).to include(a_string_matching(/format "svg"/), a_string_matching(/status "planned"/))
      expect(problems[1]).to eq(["blocked:model row needs a reason"])
      expect(problems[2]).to eq(["an implemented row must not carry a reason"])
    end

    it "accepts a blocked row that carries a reason" do
      write(dir, "x.yml", good.sub("implemented", "not_checkable").sub("reason: null", "reason: 'ignored on receipt'"))
      expect(described_class.problems(described_class.rows(dir).first)).to eq([])
    end

    it "accepts a deferred row only with a reason" do
      write(dir, "x.yml", good.sub("implemented", "deferred").sub("reason: null", "reason: 'readable, rule not written'") +
                          good.sub("a.b", "a.c").sub("implemented", "deferred"))
      problems = described_class.rows(dir).map { |row| described_class.problems(row) }
      expect(problems).to eq([[], ["deferred row needs a reason"]])
    end

    it "refuses a file that is not a list and a row with unknown keys" do
      write(dir, "x.yml", "id: a\n")
      expect { described_class.rows(dir) }.to raise_error(ArgumentError, /expected an Array/)
      write(dir, "x.yml", good.sub("status:", "stauts:"))
      expect { described_class.rows(dir) }.to raise_error(ArgumentError, /unknown keys/)
    end
  end
end
