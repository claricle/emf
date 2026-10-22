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
end
