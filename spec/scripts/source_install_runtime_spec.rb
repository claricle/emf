# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "spec_helper"

RSpec.describe "source gem installed runtime" do
  root = File.expand_path("../..", __dir__)

  before(:all) do
    @tmp = Dir.mktmpdir("emf-source-runtime-spec")
    @packages = File.join(@tmp, "packages")
    out, err, status = Open3.capture3(RbConfig.ruby, File.join(root, "script/build_native_gem"),
                                      "--platform", "ruby", "--output", @packages)
    raise "source package failed: #{out} #{err}" unless status.success?

    # Repackage the real locally installed dependency; no network or substitute implementation.
    dependency = Gem::Specification.find_by_name("bindata").dup
    Dir.chdir(dependency.full_gem_path) do
      dependency.files = Dir.glob("**/*").select { |path| File.file?(path) }
      Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
        Gem::Package.build(dependency, true, false, File.join(@packages, "#{dependency.full_name}.gem"))
      end
    end
  end

  after(:all) { FileUtils.rm_rf(@tmp) if @tmp }

  let(:directory) { @packages }
  let(:environment) { { "PATH" => "", "RUBYOPT" => nil, "BUNDLER_SETUP" => nil } }
  let(:arguments) { ["--resolve-dependencies"] }
  subject(:result) do
    Open3.capture3(environment, RbConfig.ruby, File.join(root, "script/native_install_smoke"),
                   "--directory", directory, "--platform", "ruby", "--require-native", "--forbid-compiler", *arguments)
  end

  it "resolves BinData offline and preserves installed mutable-wire APIs in auto and Ruby modes" do
    out, err, status = result
    expect([status.exitstatus, err]).to eq([0, ""])
    %w[auto ruby].each do |mode|
      expect(out).to include("source runtime #{mode}: installed=true mutable_wire=true roundtrip=true " \
                             "invalid_input=FormatError native_loaded=false")
    end
    expect(out).to include("compilers on PATH: none", "native install smoke passed (ruby)")
  end

  context "without the dependency package" do
    let(:directory) { File.join(@tmp, "missing-dependency") }
    before do
      FileUtils.mkdir_p(directory)
      FileUtils.cp(Dir.glob(File.join(@packages, "emf-*.gem")).first, directory)
    end

    it "reports dependency resolution failure rather than runtime availability success" do
      out, err, status = result
      expect(status.exitstatus).to eq(1)
      expect(err).to include("gem install failed", "bindata")
      expect(out).not_to include("native install smoke passed")
    end
  end

  context "with a contaminated parent Ruby and Bundler environment" do
    let(:environment) do
      super().merge("RUBYLIB" => File.join(@tmp, "poison"), "BUNDLE_GEMFILE" => File.join(@tmp, "missing-Gemfile"),
                    "BUNDLE_BIN_PATH" => "missing-bundle", "BUNDLE_LOCKFILE" => "missing-lock",
                    "EMF_BACKEND" => "native", "EMF_NATIVE_LIBRARY" => "missing-library")
    end
    before do
      FileUtils.mkdir_p(environment.fetch("RUBYLIB"))
      File.write(File.join(environment.fetch("RUBYLIB"), "emf.rb"), 'abort "loaded parent checkout poison"')
    end

    it "loads the installed source gem in fresh backend processes" do
      out, err, status = result
      expect([status.exitstatus, err]).to eq([0, ""])
      expect(out).to include("source runtime auto: installed=true", "source runtime ruby: installed=true")
    end
  end
end
