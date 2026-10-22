# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Emf::Conformance::Registry do
  it "loads every rule file in a directory, so a new family needs no list edit" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "wmf_probe.rb"), <<~RUBY)
        Emf::Conformance::Registry.loading.register(id: "wmf.probe", formats: [:wmf], citation: "MS-WMF 2.3.1",
                                                    kind: :probe) { |_context| [{ message: "probe" }] }
      RUBY
      registry = described_class.load_from(dir)
      expect(registry.map(&:id)).to eq(["wmf.probe"])
      expect(registry.rules_for(:wmf).map(&:id)).to eq(["wmf.probe"])
      expect(registry.rules_for(:emf)).to be_empty
    end
  end

  it "rejects a duplicate id and a rule without a check" do
    registry = described_class.new
    registry.register(id: "a.b", formats: [:emf], citation: "c", kind: :k) { [] }
    expect { registry.register(id: "a.b", formats: [:emf], citation: "c", kind: :k) { [] } }.to raise_error(ArgumentError, /already/)
    expect { registry.register(id: "a.c", formats: [:emf], citation: "c", kind: :k) }.to raise_error(ArgumentError, /check block/)
  end

  it "applies EMF rules to EMF+ metafiles but EMF+ rules only to EMF+" do
    default = described_class.default
    expect(default["emf.header.bytes"].applies_to?(:emf_plus)).to be(true)
    expect(default["emfplus.record.unknown_type"].applies_to?(:emf)).to be(false)
  end
  it "keeps a rule file it loaded from running again when something requires it later" do
    registry = Emf::Conformance::Registry.default
    ids = registry.map(&:id)
    file = File.expand_path("../../../lib/emf/conformance/rules/emf_bitmap.rb", __dir__)
    expect { require file }.not_to raise_error
    expect(registry.map(&:id)).to eq(ids)
  end

  it "still rejects a second rule with the same id from another place" do
    registry = described_class.new
    registry.register(id: "x.dup", formats: [:emf], citation: "c", kind: :k) { [] }
    expect { registry.register(id: "x.dup", formats: [:emf], citation: "c", kind: :k) { [] } }
      .to raise_error(ArgumentError, /already registered/)
  end
  it "rejects a duplicate id registered from the same line while loading, as in a loop" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "loop.rb"), <<~RUBY)
        2.times { |n| Emf::Conformance::Registry.loading.register(id: "x.loop", formats: [:emf], citation: "c\#{n}", kind: :k) { [] } }
      RUBY
      expect { described_class.load_from(dir) }.to raise_error(ArgumentError, /x.loop already registered/)
    end
  end

  it "starts every rule file with the load guard, so a direct require never runs it a second time" do
    guard = "return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)"
    files = Dir[File.join(described_class::RULES_DIR, "*.rb")]
    expect(files).not_to be_empty
    files.each do |file|
      code = File.readlines(file).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
      expect(code.first).to eq(guard), file
    end
  end

  it "rejects a duplicate id registered after loading, even from a helper in a loaded rule file" do
    registry = described_class.default
    rule = registry.first
    expect do
      registry.register(id: rule.id, formats: rule.formats, citation: "other", kind: rule.kind, &rule.check)
    end.to raise_error(ArgumentError, /already registered/)
  end

  it "builds one default registry when first used from several threads" do
    described_class.instance_variable_set(:@default, nil)
    defaults = Array.new(4) { Thread.new { described_class.default } }.map(&:value)
    expect(defaults.map(&:object_id).uniq.size).to eq(1)
  end
end
