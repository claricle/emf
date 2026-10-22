# frozen_string_literal: true

require "spec_helper"

# The lens reads its rule manifest at run time (WMF rejection citations), so an installed gem must carry it.
RSpec.describe "Emf::Conformance packaging" do
  it "ships every rule manifest file in the gem" do
    root = File.expand_path("../../..", __dir__)
    files = Dir.chdir(root) { Gem::Specification.load("emf.gemspec").files }
    manifests = Dir.chdir(root) { Dir.glob("lib/emf/conformance/manifest/*.yml") }
    expect(manifests).not_to be_empty
    expect(manifests - files).to be_empty
  end
end
