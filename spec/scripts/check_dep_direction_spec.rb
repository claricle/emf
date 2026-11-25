# frozen_string_literal: true

require "json"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "script/check_dep_direction" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(root, "script", "check_dep_direction") }

  def run_script(*arguments)
    Open3.capture2e(RbConfig.ruby, script, *arguments, chdir: root)
  end

  def metadata_with(edges)
    members = %w[emf-core emf-ffi png-model dib-model dib-png]
    dependencies = Hash.new { |hash, crate| hash[crate] = [] }
    edges.each do |from, to, kind|
      dependencies[from] << { "name" => to, "kind" => kind == "normal" ? nil : kind, "path" => "/#{to}", "optional" => false }
    end
    {
      "workspace_members" => members,
      "packages" => members.map do |crate|
        { "id" => crate, "name" => crate, "manifest_path" => "/#{crate}/Cargo.toml", "dependencies" => dependencies[crate] }
      end
    }
  end

  it "passes its own negative self-tests" do
    output, status = run_script("--self-test")
    expect(status).to be_success
    expect(output).to include("self-test: all cases pass")
  end

  it "fails when a format model depends on a transformer, naming the illegal edge" do
    metadata = metadata_with([%w[png-model dib-png dev]])
    Dir.mktmpdir do |dir|
      path = File.join(dir, "metadata.json")
      File.write(path, JSON.generate(metadata))
      output, status = run_script("--metadata-file", path)
      expect(status).not_to be_success
      expect(output).to include("ILLEGAL EDGE: png-model --(dev)--> dib-png")
      expect(output).to include("models must not depend on transformers, engines, bindings, or other models")
    end
  end
end
