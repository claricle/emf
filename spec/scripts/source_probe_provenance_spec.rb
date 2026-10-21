# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "script/build_native_gem source provenance" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:revision) { "1" * 40 }
  let(:arguments) { ["--platform", "ruby", "--revision", revision] }
  let(:harness) do
    <<~'RUBY'
      require "fileutils"
      require "json"
      require "open3"
      require "rubygems/package"
      require "tmpdir"

      report = { writes: {}, copies: [], moves: [], directories: [], commands: [] }
      at_exit { puts JSON.generate(report) }
      FileUtils.define_singleton_method(:mkdir_p) { |path| report[:directories] << path }
      FileUtils.define_singleton_method(:cp) { |*paths| report[:copies] << paths }
      FileUtils.define_singleton_method(:mv) { |*paths| report[:moves] << paths }
      File.define_singleton_method(:write) { |path, data| report[:writes][File.basename(path)] = JSON.parse(data) }
      Dir.define_singleton_method(:mktmpdir) { |*_args, &block| block.call("/stub-stage") }
      Dir.define_singleton_method(:chdir) { |*_args, &block| block.call }
      Open3.define_singleton_method(:capture2) do |*args, **_options|
        report[:commands] << args
        [args.first == "git" ? "#{'1' * 40}\n" : "#{args.first} test-version\n",
         Struct.new(:success?).new(true)]
      end
      Gem::Specification.define_singleton_method(:load) do |_path|
        Gem::Specification.new do |spec|
          spec.name = "emf"
          spec.version = "1.2.3"
          spec.files = ["README.adoc"]
          spec.metadata = { "preserved" => "value" }
        end
      end
      Gem::Package.define_singleton_method(:build) do |spec, *_args|
        report[:package] = { platform: spec.platform.to_s, metadata: spec.metadata, files: spec.files }
        "emf-test.gem"
      end
      load ARGV.shift
    RUBY
  end
  let(:result) do
    Open3.capture3(RbConfig.ruby, "-e", harness, File.join(root, "script/build_native_gem"),
                   "--output", "/stub-output", *arguments)
  end
  let(:report) { JSON.parse(result.first.lines.last) }

  it "binds source metadata to the matching checkout and preserves source files" do
    expect([result.last.exitstatus, result[1]]).to eq([0, ""])
    expect(report.fetch("package")).to eq(
      "platform" => "ruby", "files" => ["README.adoc"], "metadata" => {
        "preserved" => "value", "emf_revision" => revision,
        "emf_cargo_lock_sha256" => Digest::SHA256.file(File.join(root, "emf-rs/Cargo.lock")).hexdigest,
        "emf_crate_version" => "0.0.0"
      }
    )
    expect(report.fetch("writes")).to be_empty
    expect(report.fetch("moves")).to eq([["/stub-stage/emf-test.gem", "/stub-output"]])
  end

  context "without --revision" do
    let(:arguments) { ["--platform", "ruby"] }

    it "records the actual checkout revision" do
      expect([result.last.exitstatus, result[1]]).to eq([0, ""])
      expect(report.fetch("package").fetch("metadata")).to include("emf_revision" => revision)
      expect(report.fetch("commands")).to eq([%w[git rev-parse HEAD]])
    end
  end

  context "with a stale revision" do
    let(:arguments) { ["--platform", "ruby", "--revision", "0" * 40] }

    it "rejects the revision before writing or packaging anything" do
      expect(result.last.exitstatus).to eq(1)
      expect(result[1]).to include("source checkout revision #{revision} != #{'0' * 40}")
      expect(report).not_to have_key("package")
      expect(report.values_at("writes", "copies", "moves", "directories")).to eq([{}, [], [], []])
    end
  end

  context "with a source library argument" do
    let(:arguments) { ["--platform", "ruby", "--library", File.join(root, "emf-rs/Cargo.lock")] }

    it "preserves the source-only validation before writing or packaging" do
      expect(result.last.exitstatus).to eq(1)
      expect(result[1]).to include("--platform ruby builds the source gem and takes no --library")
      expect(report).not_to have_key("package")
      expect(report.values_at("writes", "copies", "moves", "directories", "commands")).to eq([{}, [], [], [], []])
    end
  end

  context "with a native platform" do
    let(:library) { File.join(root, "emf-rs/Cargo.lock") }
    let(:arguments) do
      ["--platform", "x86_64-linux", "--library", library, "--abi-version", "1",
       "--target", "x86_64-unknown-linux-gnu", "--revision", "2" * 40]
    end

    it "preserves native packaging and the supplied native provenance" do
      expect([result.last.exitstatus, result[1]]).to eq([0, ""])
      expect(report.fetch("package")).to include("platform" => "x86_64-linux", "metadata" => { "preserved" => "value" })
      expect(report.fetch("package").fetch("files")).to include(
        "README.adoc", "lib/emf/native/x86_64-linux/Cargo.lock", "lib/emf/native/platforms.json", "lib/emf/native/provenance.json"
      )
      expect(report.fetch("writes").fetch("provenance.json")).to include(
        "revision" => "2" * 40, "target" => "x86_64-unknown-linux-gnu", "gem_version" => "1.2.3"
      )
      expect(report.fetch("writes").fetch("platforms.json")).to include("abi_version" => 1)
      expect(report.fetch("commands")).to eq([["rustc", "--version"], ["cargo", "--version"]])
    end
  end
end
