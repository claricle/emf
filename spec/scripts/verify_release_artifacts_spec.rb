# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "yaml"

require "spec_helper"

RSpec.describe "script/verify_release_artifacts" do
  rows = %w[x86_64-linux-gnu arm64-darwin].freeze
  revision = "b" * 40

  def root = File.expand_path("../..", __dir__)

  before(:all) do
    @tmp = Dir.mktmpdir("emf-release-verify-spec")
    @tools = File.join(@tmp, "bin")
    FileUtils.mkdir_p(@tools)
    %w[rustc cargo].each do |tool|
      File.write(File.join(@tools, tool), "#!/bin/sh\necho '#{tool} 0.0.0 (fake)'\n")
      File.chmod(0o755, File.join(@tools, tool))
    end
    File.write(File.join(@tools, "git"), "#!/bin/sh\necho #{'b' * 40}\n")
    File.chmod(0o755, File.join(@tools, "git"))
    @libraries = File.join(@tmp, "libs")
    FileUtils.mkdir_p(@libraries)
  end

  after(:all) { FileUtils.rm_rf(@tmp) }

  def build(*args, output:)
    env = { "PATH" => "#{@tools}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" }
    _out, err, status = Open3.capture3(env, RbConfig.ruby, File.join(root, "script/build_native_gem"), *args, "--output", output)
    raise "build failed: #{err}" unless status.success?
  end

  def build_platform(platform, output, revision:, abi: 1, content: platform)
    library = File.join(@libraries, "#{platform}-#{Digest::SHA256.hexdigest(content)[0, 8]}", "libemf_ffi.so")
    FileUtils.mkdir_p(File.dirname(library))
    File.write(library, content)
    target = { "x86_64-linux-gnu" => "x86_64-unknown-linux-gnu", "arm64-darwin" => "aarch64-apple-darwin" }
             .fetch(platform, "x86_64-pc-windows-gnu")
    build("--platform", platform, "--library", library, "--abi-version", abi.to_s, "--target", target,
          "--revision", revision, output: output)
  end

  def stage(dir_name, rows:, revision:, source: true, abi: {})
    dir = File.join(@tmp, dir_name)
    rows.each { |row| build_platform(row, File.join(dir, row), revision: revision, abi: abi.fetch(row, 1)) }
    if source
      env = { "PATH" => "#{@tools}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" }
      _out, err, status = Open3.capture3(env, RbConfig.ruby, File.join(root, "script/build_source_release_gem"),
                                         "--revision", "b" * 40, "--output", File.join(dir, "source"))
      raise "source build failed: #{err}" unless status.success?
    end
    dir
  end

  def verify(dir, revision: "b" * 40, version: Emf::VERSION, platforms: %w[x86_64-linux-gnu arm64-darwin], output: nil)
    out = output || File.join(@tmp, "out-#{File.basename(dir)}-#{rand(1 << 32)}")
    _o, err, status = Open3.capture3(RbConfig.ruby, File.join(root, "script/verify_release_artifacts"), "--directory", dir,
                                     "--revision", revision, "--version", version, "--platforms", platforms.join(","), "--output", out)
    [status.exitstatus, err, out]
  end

  it "passes a complete set and writes the gems with a SHA256SUMS that matches them" do
    dir = stage("good", rows: rows, revision: revision)
    code, err, out = verify(dir)
    sums = File.readlines(File.join(out, "SHA256SUMS"), chomp: true)
    expect([code, err, Dir.glob(File.join(out, "*.gem")).size]).to eq([0, "", 3])
    expect(sums.map { |line| line.split("  ") }).to all(satisfy { |sum, name| Digest::SHA256.file(File.join(out, name)).hexdigest == sum })
  end

  it "rejects missing source provenance before writing output" do
    dir = stage("source-unbound", rows: rows, revision: revision, source: false)
    build("--platform", "ruby", output: File.join(dir, "source"))
    code, err, out = verify(dir)
    expect([code, err, File.exist?(out)]).to match([1, /source provenance.*revision/, false])
  end

  it "fails on a missing row and writes nothing" do
    dir = stage("missing", rows: rows.first(1), revision: revision)
    code, err, out = verify(dir)
    expect([code, err, File.exist?(out)]).to match([1, /missing arm64-darwin gem/, false])
  end

  it "fails on a missing source gem" do
    dir = stage("no-source", rows: rows, revision: revision, source: false)
    expect(verify(dir)).to match([1, /missing ruby gem/, anything])
  end

  it "fails on a duplicate gem for one row" do
    dir = stage("dup", rows: rows, revision: revision)
    build_platform("arm64-darwin", File.join(dir, "again"), revision: revision, content: "another build")
    expect(verify(dir)).to match([1, /duplicate arm64-darwin gem/, anything])
  end

  it "fails on an unexpected extra platform gem" do
    dir = stage("extra", rows: rows, revision: revision)
    build_platform("x64-mingw-ucrt", File.join(dir, "extra"), revision: revision)
    expect(verify(dir)).to match([1, /unexpected x64-mingw-ucrt gem/, anything])
  end

  it "fails when the packaged library no longer matches its recorded sha256" do
    dir = stage("sha", rows: rows, revision: revision)
    gem_path = Dir.glob(File.join(dir, "arm64-darwin", "*.gem")).first
    tamper_library(gem_path)
    expect(verify(dir)).to match([1, /library_sha256 .* != actual|sha256 mismatch/, anything])
  end

  it "fails when a platform gem records another revision" do
    dir = stage("revision", rows: rows, revision: revision)
    expect(verify(dir, revision: "c" * 40)).to match([1, /provenance.json revision #{revision} != #{'c' * 40}/, anything])
  end

  it "fails when the expected version differs from the gems" do
    dir = stage("version", rows: rows, revision: revision)
    expect(verify(dir, version: "9.9.9")).to match([1, /version #{Emf::VERSION} != 9\.9\.9/o, anything])
  end

  it "fails when a platform gem reports another ABI version" do
    dir = stage("abi", rows: rows, revision: revision, abi: { "arm64-darwin" => 2 })
    expect(verify(dir)).to match([1, /arm64-darwin.*abi_version 2 != 1/, anything])
  end

  it "rejects a mixed-revision release before writing output" do
    dir = stage("mixed-revision", rows: rows.first(1), revision: revision)
    build_platform("arm64-darwin", File.join(dir, "arm64-darwin"), revision: "c" * 40)
    code, err, out = verify(dir)
    expect([code, err, File.exist?(out)]).to match([1, /provenance.json revision #{'c' * 40} != #{revision}/, false])
  end

  {
    "target" => "x86_64-apple-darwin",
    "cargo_lock_sha256" => "0" * 64,
    "crate_version" => "999.0.0"
  }.each do |field, value|
    it "rejects mismatched provenance #{field} even when its revision and library hash match" do
      dir = stage("provenance-#{field}", rows: rows, revision: revision)
      path = Dir.glob(File.join(dir, "arm64-darwin", "*.gem")).first
      Dir.mktmpdir("emf-provenance", @tmp) do |tmp|
        package = Gem::Package.new(path)
        package.extract_files(tmp)
        provenance = File.join(tmp, "lib/emf/native/provenance.json")
        data = JSON.parse(File.read(provenance))
        data[field] = value
        File.write(provenance, JSON.generate(data))
        Dir.chdir(tmp) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(package.spec, true) } }
        FileUtils.cp(Dir.glob(File.join(tmp, "*.gem")).first, path)
      end
      code, err, out = verify(dir)
      expect([code, err, File.exist?(out)]).to match([1, /#{field} .*#{Regexp.escape(value)}.* !=/, false])
    end
  end

  {
    "emf_revision" => "c" * 40,
    "emf_cargo_lock_sha256" => "0" * 64,
    "emf_crate_version" => "999.0.0"
  }.each do |field, value|
    it "rejects source #{field} that disagrees with the release checkout" do
      dir = stage("source-#{field}", rows: rows, revision: revision)
      path = Dir.glob(File.join(dir, "source", "*.gem")).first
      Dir.mktmpdir("emf-source-metadata", @tmp) do |tmp|
        package = Gem::Package.new(path)
        package.extract_files(tmp)
        spec = package.spec
        spec.metadata[field] = value
        Dir.chdir(tmp) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec, true) } }
        FileUtils.cp(Dir.glob(File.join(tmp, "*.gem")).first, path)
      end
      code, err, out = verify(dir)
      expect([code, err, File.exist?(out)]).to match([1, /source provenance #{field} .*#{Regexp.escape(value)}.* !=/, false])
    end
  end

  it "rejects aliased input names before flattening can overwrite a verified gem" do
    dir = stage("alias", rows: rows, revision: revision)
    Dir.glob(File.join(dir, "*", "*.gem")).each { |path| FileUtils.mv(path, File.join(File.dirname(path), "same.gem")) }
    code, err, out = verify(dir)
    expect([code, err, File.exist?(out)]).to match([1, /filename same.gem != emf-/, false])
  end

  it "rejects a nonempty output directory without changing its previous contents" do
    dir = stage("stale-output", rows: rows, revision: revision)
    output = File.join(@tmp, "stale-output-destination")
    FileUtils.mkdir_p(output)
    stale = File.join(output, "emf-0.0.0.gem")
    File.write(stale, "previous artifact")
    code, err, = verify(dir, output: output)
    expect([code, err, Dir.children(output),
            File.read(stale)]).to match([1, /output.*must be empty/, ["emf-0.0.0.gem"], "previous artifact"])
  end

  it "keeps the workflow's build matrix and verified platform list identical" do
    workflow = YAML.safe_load_file(File.join(root, ".github/workflows/release.yml"))
    built = workflow.dig("jobs", "build", "strategy", "matrix", "row").map { |row| row["platform"] }
    listed = workflow.dig("jobs", "verify", "env", "PLATFORMS").split(",")
    expect(built).to eq(listed)
    expect(built.size).to eq(7)
    source = workflow.dig("jobs", "source", "steps").find { |step| step["name"] == "Build the source gem" }
    expect(source["env"]).to eq("RELEASE_SHA" => "${{ needs.version.outputs.sha }}")
    expect(source["run"]).to eq('script/build_source_release_gem --revision "$RELEASE_SHA" --output source-out')
    targets = workflow.dig("jobs", "build", "strategy", "matrix", "row").to_h { |row| [row["platform"], row["target"]] }
    script = File.read(File.join(root, "script/verify_release_artifacts"))
    targets.each { |platform, target| expect(script).to include("\"#{platform}\" => \"#{target}\"") }
  end

  def tamper_library(gem_path)
    Dir.mktmpdir("emf-tamper", @tmp) do |dir|
      package = Gem::Package.new(gem_path)
      package.extract_files(dir)
      spec = package.spec
      File.write(Dir.glob(File.join(dir, "lib/emf/native/*/libemf_ffi.so")).first, "tampered")
      FileUtils.rm(gem_path)
      Dir.chdir(dir) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec, true) } }
      FileUtils.mv(Dir.glob(File.join(dir, "*.gem")), File.dirname(gem_path))
    end
  end
end
