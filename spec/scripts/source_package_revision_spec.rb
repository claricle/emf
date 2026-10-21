# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"
require "spec_helper"

RSpec.describe "script/check_native_package source revision binding" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:revision) { "a" * 40 }
  let(:arguments) { ["--revision", revision] }
  let(:metadata) do
    {
      "emf_revision" => revision,
      "emf_cargo_lock_sha256" => Digest::SHA256.file(File.join(root, "emf-rs/Cargo.lock")).hexdigest,
      "emf_crate_version" => File.read(File.join(root, "emf-rs/crates/emf-ffi/Cargo.toml"))[/^version\s*=\s*"([^"]+)"/, 1]
    }
  end
  let(:platform) { "ruby" }
  let(:files) { {} }
  let(:extra_contents) { [] }
  let(:extensions) { [] }
  let(:bootstrap) do
    <<~RUBY
      require "fileutils"
      require "json"
      require "rubygems/package"
      script = ARGV.shift
      data = JSON.parse(STDIN.read)
      root = File.expand_path("..", File.dirname(script))
      spec = Dir.chdir(root) { Gem::Specification.load("emf.gemspec") }
      contents = spec.files + data.fetch("files").keys + data.fetch("extra_contents")
      spec.platform = data.fetch("platform")
      spec.add_runtime_dependency("fiddle", "~> 1.1") unless data.fetch("platform") == "ruby"
      spec.metadata = data.fetch("metadata")
      spec.extensions = data.fetch("extensions")
      package = Object.new
      package.define_singleton_method(:spec) { spec }
      package.define_singleton_method(:contents) { contents }
      package.define_singleton_method(:extract_files) do |directory|
        data.fetch("files").each do |relative, bytes|
          path = File.join(directory, relative)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, bytes)
        end
      end
      Gem::Package.define_singleton_method(:new) { |_path| package }
      original_glob = Dir.method(:glob)
      Dir.define_singleton_method(:glob) do |pattern, *args, **kwargs, &block|
        pattern == "stub-packages/*.gem" ? ["release.gem"] : original_glob.call(pattern, *args, **kwargs, &block)
      end
      ARGV.unshift("--directory", "stub-packages")
      load script
    RUBY
  end

  subject(:result) do
    input = { metadata: metadata, platform: platform, files: files, extra_contents: extra_contents, extensions: extensions }
    Open3.capture3(RbConfig.ruby, "-e", bootstrap, File.join(root, "script/check_native_package"), *arguments,
                   stdin_data: JSON.generate(input))
  end

  it "accepts source metadata matching the full revision, lock and crate version" do
    out, err, status = result
    expect([status.exitstatus, err, out]).to eq([0, "", "native package check passed\n"])
  end

  {
    "emf_revision" => "b" * 40,
    "emf_cargo_lock_sha256" => "0" * 64,
    "emf_crate_version" => "999.0.0"
  }.each do |field, wrong|
    context "with stale #{field}" do
      before { metadata[field] = wrong }

      it "rejects source metadata belonging to another release identity" do
        _out, err, status = result
        expect(status.exitstatus).to eq(1)
        expect(err).to include("release.gem: source provenance #{field} #{wrong.inspect} !=")
      end
    end

    context "without #{field}" do
      before { metadata.delete(field) }

      it "rejects incomplete source metadata" do
        _out, err, status = result
        expect(status.exitstatus).to eq(1)
        expect(err).to include("release.gem: source provenance #{field} nil !=")
      end
    end
  end

  context "without a requested revision" do
    let(:arguments) { [] }
    let(:metadata) { {} }

    it "preserves the ordinary source package check without release metadata" do
      _out, err, status = result
      expect([status.exitstatus, err]).to eq([0, ""])
    end
  end

  context "with source payload violations" do
    let(:extra_contents) { ["lib/stray.so", "emf-rs/Cargo.lock", "emf-rs/src/lib.rs"] }
    let(:extensions) { ["ext/emf/extconf.rb"] }

    it "preserves native library, Rust payload and extension rejections" do
      _out, err, status = result
      expect(status.exitstatus).to eq(1)
      expect(err).to include("source gem contains native library lib/stray.so", "source gem contains Rust file emf-rs/Cargo.lock",
                             "source gem contains Rust file emf-rs/src/lib.rs", "source gem declares extensions")
    end
  end

  ["abc123", "g" * 40, "A" * 40, "a" * 39, "a" * 41, "#{'a' * 40}\n", ""].each do |invalid|
    context "with malformed expected revision #{invalid.inspect}" do
      let(:arguments) { ["--revision", invalid] }

      it "rejects the revision before accepting any package" do
        out, err, status = result
        expect([status.exitstatus, out]).to eq([1, ""])
        expect(err).to include("--revision must be a full 40-character lowercase git SHA")
      end
    end
  end

  context "with a native package" do
    let(:platform) { "x86_64-linux" }
    let(:metadata) { {} }
    let(:library) { "lib/emf/native/#{platform}/libemf.so" }
    let(:payload) { "stub native library bytes" }
    let(:provenance) do
      {
        platform: platform, target: "x86_64-unknown-linux-gnu", library_sha256: Digest::SHA256.hexdigest(payload),
        rustc: "rustc stub", cargo: "cargo stub", cargo_lock_sha256: "0" * 64,
        crate_version: "0.0.0", revision: revision, gem_version: Emf::VERSION
      }
    end
    let(:files) do
      {
        library => payload,
        "lib/emf/native/platforms.json" => JSON.generate(platform: platform, library: "libemf.so", abi_version: 1,
                                                         sha256: Digest::SHA256.hexdigest(payload)),
        "lib/emf/native/provenance.json" => JSON.generate(provenance)
      }
    end

    it "accepts existing native provenance without source metadata" do
      _out, err, status = result
      expect([status.exitstatus, err]).to eq([0, ""])
    end

    context "with another recorded native revision" do
      before { provenance[:revision] = "b" * 40 }

      it "preserves native revision mismatch rejection" do
        _out, err, status = result
        expect(status.exitstatus).to eq(1)
        expect(err).to include("provenance.json revision #{'b' * 40} != #{revision}")
      end
    end

    context "with a damaged native library hash" do
      before { provenance[:library_sha256] = "0" * 64 }

      it "preserves native payload hash rejection" do
        _out, err, status = result
        expect(status.exitstatus).to eq(1)
        expect(err).to include("provenance.json library_sha256 #{'0' * 64} != actual")
      end
    end
  end
end
