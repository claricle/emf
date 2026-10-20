# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

require "spec_helper"

RSpec.describe "native gem packaging scripts" do
  root = File.expand_path("../..", __dir__)
  probe = File.join(root, "script/platform_probe/hello")
  library_name = case RbConfig::CONFIG["host_os"]
                 when /darwin/ then "libemf_probe_hello.dylib"
                 when /mingw|mswin/ then "emf_probe_hello.dll"
                 else "libemf_probe_hello.so"
                 end
  cargo = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "cargo")) }

  before(:all) do
    skip "cargo is not on PATH; the probe library cannot be built" unless cargo

    @tmp = Dir.mktmpdir("emf-native-package")
    target = File.join(@tmp, "target")
    _out, status = Open3.capture2e({ "CARGO_TARGET_DIR" => target }, "cargo", "build", "--locked", "--release", chdir: probe)
    raise "probe build failed" unless status.success?

    @library = File.join(target, "release", library_name)
    @platform = Gem::Platform.local.to_s
    @good = File.join(@tmp, "good")
    script = ->(name, *args) { Open3.capture3(RbConfig.ruby, File.join(root, "script", name), *args) }
    [[@platform, "--library", @library, "--abi-version", "1"], ["ruby"]].each do |platform, *rest|
      _o, e, s = script.call("build_native_gem", "--platform", platform, "--output", @good, *rest)
      raise "build failed: #{e}" unless s.success?
    end
  end

  after(:all) { FileUtils.rm_rf(@tmp) if @tmp }

  let(:script) { ->(name, *args) { Open3.capture3(RbConfig.ruby, File.join(root, "script", name), *args) } }
  let(:platform_gem) { Dir.glob(File.join(@good, "*-#{@platform}.gem")).first }
  let(:ruby_gem) { Dir.glob(File.join(@good, "emf-*.gem")).find { |path| path != platform_gem } }
  let(:rebuild) do
    lambda do |gem_path, &tamper|
      out = Dir.mktmpdir("emf-tampered", @tmp)
      Dir.mktmpdir("emf-extract", @tmp) do |dir|
        package = Gem::Package.new(gem_path)
        package.extract_files(dir)
        spec = package.spec
        tamper.call(dir, spec)
        Dir.chdir(dir) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec, true) } }
        FileUtils.mv(Dir.glob(File.join(dir, "*.gem")), out)
      end
      out
    end
  end
  let(:check) { ->(dir) { script.call("check_native_package", "--directory", dir) } }

  it "passes a platform gem and a source gem built from the probe library" do
    _out, err, status = check.call(@good)
    expect([status.exitstatus, err]).to eq([0, ""])
  end

  it "keeps the repository tree and the source gem free of native files" do
    names = Gem::Package.new(ruby_gem).contents
    expect(names.grep(/\.(so|dylib|dll)\z|Cargo|\.rs\z/)).to be_empty
    expect(Dir.glob(File.join(root, "lib/**/*.{so,dylib,dll}"))).to be_empty
  end

  it "records platform, library name, sha256 and ABI version for the platform gem" do
    Dir.mktmpdir("emf-manifest", @tmp) do |dir|
      Gem::Package.new(platform_gem).extract_files(dir)
      data = JSON.parse(File.read(File.join(dir, "lib/emf/native/platforms.json")))
      expect(data).to include("platform" => @platform, "library" => library_name, "abi_version" => 1,
                              "sha256" => Digest::SHA256.file(@library).hexdigest)
    end
  end

  it "installs the platform gem without compiling and loads it through Fiddle" do
    out, _err, status = script.call("native_install_smoke", "--directory", @good, "--platform", @platform,
                                    "--abi-symbol", "emf_probe_abi_version", "--require-native")
    expect([status.exitstatus, out]).to match([0, /reports ABI 1/])
  end

  it "names the real exported ABI symbol by default and reports a missing symbol as a failure" do
    _out, err, status = script.call("native_install_smoke", "--directory", @good, "--platform", @platform, "--require-native")
    expect([status.exitstatus, err]).to match([1, /native install smoke failed: .*does not export "emf_abi_version"/])
  end

  it "fails the install when dependencies must be resolved and bindata is not in the directory" do
    _out, err, status = script.call("native_install_smoke", "--directory", @good, "--platform", @platform,
                                    "--abi-symbol", "emf_probe_abi_version", "--require-native", "--resolve-dependencies")
    expect([status.exitstatus, err]).to match([1, /gem install failed.*bindata/m])
  end

  it "fails the smoke run when a compiler is on PATH and --forbid-compiler is given" do
    with_compiler = Dir.mktmpdir("emf-fake-cc", @tmp)
    FileUtils.touch(File.join(with_compiler, "cc"))
    File.chmod(0o755, File.join(with_compiler, "cc"))
    out, err, status = Open3.capture3({ "PATH" => with_compiler }, RbConfig.ruby, File.join(root, "script/native_install_smoke"),
                                      "--directory", @good, "--platform", @platform, "--forbid-compiler")
    expect([status.exitstatus, err, out]).to match([1, /compiler on PATH: cc/, ""])
  end

  it "finds a Windows compiler through PATHEXT when --forbid-compiler is given" do
    with_compiler = Dir.mktmpdir("emf-fake-gcc", @tmp)
    FileUtils.touch(File.join(with_compiler, "gcc.exe"))
    File.chmod(0o755, File.join(with_compiler, "gcc.exe"))
    out, err, status = Open3.capture3({ "PATH" => with_compiler, "PATHEXT" => ".exe" }, RbConfig.ruby,
                                      File.join(root, "script/native_install_smoke"),
                                      "--directory", @good, "--platform", @platform, "--forbid-compiler")
    expect([status.exitstatus, err, out]).to match([1, /compiler on PATH: gcc/, ""])
  end

  it "rejects a platform gem missing its library" do
    dir = rebuild.call(platform_gem) do |extracted, spec|
      FileUtils.rm(Dir.glob(File.join(extracted, "lib/emf/native", spec.platform.to_s, "*")))
      spec.files -= spec.files.grep(/\.(so|dylib|dll)\z/)
    end
    _out, err, status = check.call(dir)
    expect([status.exitstatus, err]).to match([1, /expected exactly one native library, found 0/])
  end

  it "rejects a source gem containing a native library" do
    dir = rebuild.call(ruby_gem) do |extracted, spec|
      FileUtils.touch(File.join(extracted, "lib/stray.dylib"))
      spec.files += ["lib/stray.dylib"]
    end
    _out, err, status = check.call(dir)
    expect([status.exitstatus, err]).to match([1, %r{source gem contains native library lib/stray.dylib}])
  end

  it "rejects a platform gem whose sha256 does not match its library" do
    dir = rebuild.call(platform_gem) do |extracted, _spec|
      manifest = File.join(extracted, "lib/emf/native/platforms.json")
      File.write(manifest, JSON.generate(JSON.parse(File.read(manifest)).merge("sha256" => "0" * 64)))
    end
    _out, err, status = check.call(dir)
    expect([status.exitstatus, err]).to match([1, /sha256 mismatch/])
  end

  it "rejects a gem missing a file the source gemspec lists" do
    dir = rebuild.call(ruby_gem) do |extracted, spec|
      FileUtils.rm(File.join(extracted, "exe/emf"))
      spec.files -= ["exe/emf"]
      spec.executables = []
    end
    _out, err, status = check.call(dir)
    expect([status.exitstatus, err]).to match([1, %r{missing exe/emf}])
  end
end
