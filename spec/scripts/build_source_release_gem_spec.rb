# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "spec_helper"

RSpec.describe "script/build_source_release_gem" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:revision) { Open3.capture2("git", "rev-parse", "HEAD", chdir: root).first.strip }
  let(:arguments) { ["--revision", revision] }
  let(:output) { File.join(@tmp, "packages") }

  subject(:result) do
    Open3.capture3(RbConfig.ruby, File.join(root, "script/build_source_release_gem"), "--output", output, *arguments)
  end

  before { @tmp = Dir.mktmpdir("emf-source-release-spec") }
  after { FileUtils.rm_rf(@tmp) }

  it "builds a source-only gem with metadata bound to its checkout" do
    out, err, status = result
    expect([status.success?, err]).to eq([true, ""])
    path = out.strip
    package = Gem::Package.new(path)
    expect(package.spec.platform.to_s).to eq("ruby")
    expect(package.spec.version.to_s).to eq(Emf::VERSION)
    expect(package.spec.extensions).to be_empty
    expect(package.contents.grep(/\.(?:so|dylib|dll|rs)\z/)).to be_empty
    expect(package.spec.metadata).to include(
      "emf_revision" => revision,
      "emf_cargo_lock_sha256" => Digest::SHA256.file(File.join(root, "emf-rs/Cargo.lock")).hexdigest,
      "emf_crate_version" => "0.0.0"
    )
    expect(package.contents).to include("lib/emf.rb", "README.adoc", "LICENSE.txt")
  end

  context "without an explicit revision" do
    let(:arguments) { [] }

    it "records the actual checkout revision" do
      out, err, status = result
      expect([status.success?, err]).to eq([true, ""])
      expect(Gem::Package.new(out.strip).spec.metadata["emf_revision"]).to eq(revision)
    end
  end

  context "when the intended revision differs from the checkout" do
    let(:arguments) { ["--revision", "0" * 40] }

    it "fails before producing output" do
      _out, err, status = result
      expect([status.exitstatus, err, File.exist?(output)]).to match([1, /source checkout revision .* != #{'0' * 40}/, false])
    end
  end
end
