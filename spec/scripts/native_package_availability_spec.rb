# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

require "spec_helper"

RSpec.describe "native availability matrix against an installed platform gem" do
  root = File.expand_path("../..", __dir__)
  on_path = ->(tool) { ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, tool)) } }
  library = ENV["EMF_REAL_LIBRARY"] || Dir.glob(File.join(root, "emf-rs/target/release/{libemf_ffi.so,libemf_ffi.dylib,emf_ffi.dll}")).first
  toolchain = on_path.call("rustc") && on_path.call("cargo")
  compiler = %w[cc clang gcc].any?(&on_path) && !Gem.win_platform?
  fixture = File.join(root, "spec/fixtures/emf/test-000.emf")

  before(:all) do
    skip "set EMF_REAL_LIBRARY (or build emf-ffi) and have rustc and cargo on PATH" unless library && toolchain

    @tmp = Dir.mktmpdir("emf-availability-spec")
    gems = File.join(@tmp, "gems")
    build = lambda do |*args|
      _o, e, s = Open3.capture3(RbConfig.ruby, File.join(root, "script/build_native_gem"), "--output", gems, *args)
      raise "build failed: #{e}" unless s.success?
    end
    build.call("--platform", Gem::Platform.local.to_s, "--library", library, "--abi-version", "1",
               "--target", `rustc -vV`[/^host: (.+)$/, 1], "--revision", "a" * 40)
    @home = File.join(@tmp, "home")
    env = isolated_env
    copy_bindata
    out, status = Open3.capture2e(env, RbConfig.ruby, "-rrubygems/gem_runner", "-e", "Gem::GemRunner.new.run(ARGV)",
                                  "install", *Dir.glob(File.join(gems, "emf-*.gem")), "--local", "--ignore-dependencies", "--no-document")
    raise "install failed: #{out}" unless status.success?

    @out, @err, @status = run_matrix(root, library, fixture)
  end

  after(:all) { FileUtils.rm_rf(@tmp) if @tmp }

  def isolated_env
    %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP].to_h { |name| [name, nil] }
                                                                    .merge("GEM_HOME" => @home, "GEM_PATH" => @home)
  end

  # The installed gem has no .gem file to reuse offline, so its tree and spec are copied into the isolated home.
  def copy_bindata
    spec = Gem::Specification.find_by_name("bindata")
    FileUtils.mkdir_p([File.join(@home, "gems"), File.join(@home, "specifications")])
    FileUtils.cp_r(spec.full_gem_path, File.join(@home, "gems"))
    FileUtils.cp(spec.spec_file, File.join(@home, "specifications"))
  end

  def run_matrix(root, library_path, fixture)
    Open3.capture3(isolated_env, RbConfig.ruby, File.join(root, "script/platform_probe/availability_matrix.rb"),
                   "--library", library_path, "--fixture", fixture)
  end

  def rows(out) = out.lines.grep(%r{\Aavailability \S+/\w+=}).map { |line| line.delete_prefix("availability ").strip }

  it "falls back to Ruby in auto mode and reports a load error in native mode for each availability failure" do
    expected = %w[missing_library corrupt_library wrong_architecture missing_fiddle]
    expected += %w[missing_dependent_library wrong_abi_version] if compiler
    expect([@status.exitstatus, @err]).to eq([0, ""])
    expect(rows(@out)).to include(*expected.flat_map { |name| ["#{name}/auto=ruby", "#{name}/native=none Emf::Native::Unavailable"] })
  end

  it "serves a working library natively in both modes" do
    expect(rows(@out)).to include("working_library/auto=native", "working_library/native=native")
  end

  it "leaves malformed input to the native parser without a hidden Ruby fallback" do
    expect(rows(@out)).to include("malformed_garbage/auto=native Emf::FormatError", "malformed_truncated/auto=native Emf::FormatError")
  end

  it "selects the bundled library by discovery in both modes when no override is set" do
    expect(rows(@out)).to include("library_not_configured/auto=native", "library_not_configured/native=native")
  end

  it "refuses a damaged installed manifest or library: Ruby in auto mode, Unavailable when native is forced" do
    names = %w[installed_checksum_mismatch installed_abi_mismatch installed_platform_mismatch installed_library_missing]
    expect(rows(@out)).to include(*names.flat_map { |name| ["#{name}/auto=ruby", "#{name}/native=none Emf::Native::Unavailable"] })
  end

  it "fails when the library under test does not load" do
    broken = File.join(@tmp, "broken#{File.extname(library)}")
    File.binwrite(broken, File.binread(library)[0, 4096])
    out, err, status = run_matrix(root, broken, fixture)
    expect(status.exitstatus).to eq(1)
    expect(err).to include("MISMATCH working_library/native")
    expect(out).to include("availability matrix FAILED")
  end
end
