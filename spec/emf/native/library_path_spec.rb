# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "emf/native/library_path"
require "tmpdir"
require "fileutils"
require "digest"
require "json"

RSpec.describe "Bundled native library discovery" do
  let(:platform) { Gem::Platform.local.to_s }
  let(:library) { "libemf_native.dylib" }
  let(:manifest) do
    { "platform" => platform, "library" => library,
      "sha256" => Digest::SHA256.hexdigest("library"), "abi_version" => 1 }
  end
  let(:path) { File.join(@directory, platform, library) }

  around do |example|
    Dir.mktmpdir("emf-native-discovery") do |directory|
      @directory = directory
      example.run
    end
  end

  before do
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, "library")
    File.write(File.join(@directory, "platforms.json"), JSON.generate(manifest))
    allow(ENV).to receive(:fetch).with("EMF_NATIVE_LIBRARY", nil).and_return(nil)
  end

  it "loads the bundled library through the public backend without an environment override" do
    require "emf/native/loader"
    allow(Emf::Native::LibraryPath).to receive(:new).and_return(Emf::Native::LibraryPath.new(@directory))
    loader = instance_double(Emf::Native::Loader)
    expect(Emf::Native::Loader).to receive(:new).with(File.realpath(path)).and_return(loader)
    expect(Emf::Native.backend).to be_a(Emf::Native::Adapter)
  end

  it "accepts a compatible platform without an OS version" do
    compatible = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
    compatible_path = File.join(@directory, compatible, library)
    FileUtils.mkdir_p(File.dirname(compatible_path))
    FileUtils.cp(path, compatible_path) unless path == compatible_path
    File.write(File.join(@directory, "platforms.json"), JSON.generate(manifest.merge("platform" => compatible)))
    expect(Emf::Native::LibraryPath.new(@directory).call).to eq(File.realpath(compatible_path))
  end

  it "preserves an explicit library override even when the manifest is broken" do
    File.write(File.join(@directory, "platforms.json"), "{")
    allow(ENV).to receive(:fetch).with("EMF_NATIVE_LIBRARY", nil).and_return("/explicit/library")
    expect(Emf::Native::LibraryPath.new(@directory).call).to eq("/explicit/library")
  end

  it "preserves the explicit empty override" do
    allow(ENV).to receive(:fetch).with("EMF_NATIVE_LIBRARY", nil).and_return("")
    expect(Emf::Native::LibraryPath.new(@directory).call).to eq("")
  end

  it "returns no bundled library for a source gem without a manifest" do
    File.unlink(File.join(@directory, "platforms.json"))
    expect(Emf::Native::LibraryPath.new(@directory).call).to be_nil
  end

  it "reports invalid JSON as unavailable" do
    File.write(File.join(@directory, "platforms.json"), "{")
    expect { Emf::Native::LibraryPath.new(@directory).call }.to raise_error(Emf::Native::Unavailable, /manifest/)
  end

  it "reports a missing bundled library as unavailable" do
    File.unlink(path)
    expect { Emf::Native::LibraryPath.new(@directory).call }.to raise_error(Emf::Native::Unavailable, /manifest/)
  end

  it "rejects a library whose content does not match the manifest" do
    File.binwrite(path, "modified")
    expect { Emf::Native::LibraryPath.new(@directory).call }.to raise_error(Emf::Native::Unavailable, /checksum/)
  end

  it "rejects symlinks that escape the native directory" do
    Dir.mktmpdir("emf-native-outside") do |outside|
      target = File.join(outside, library)
      File.binwrite(target, "library")
      File.unlink(path)
      File.symlink(target, path)
      expect { Emf::Native::LibraryPath.new(@directory).call }.to raise_error(Emf::Native::Unavailable, /escapes/)
    end
  end

  [nil, [], { "library" => nil }, { "platform" => "../escape" }, { "library" => "../escape" },
   { "library" => "/absolute" }, { "library" => "folder\\escape" },
   { "platform" => "unknown-unsupported" }, { "abi_version" => 2 }, { "abi_version" => 1.0 },
   { "sha256" => "invalid" }].each do |invalid|
    it "rejects invalid or incompatible manifest data #{invalid.inspect}" do
      data = invalid.is_a?(Hash) ? manifest.merge(invalid) : invalid
      File.write(File.join(@directory, "platforms.json"), JSON.generate(data))
      expect { Emf::Native::LibraryPath.new(@directory).call }.to raise_error(Emf::Native::Unavailable, /manifest/)
    end
  end
end
