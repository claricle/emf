# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

require "spec_helper"

RSpec.describe "script/publish_release_gems" do
  def root = File.expand_path("../..", __dir__)

  # Fake `gem`: behaviour per file comes from <name>.push / <name>.remote files
  # under $FAKE_GEM_STATE. push logs the call; "exists" mimics rubygems.org,
  # "error" is any other failure. fetch copies <name>.remote into the cwd.
  def fake_gem = <<~'RUBY'
    #!/usr/bin/env ruby
    state = ENV.fetch("FAKE_GEM_STATE")
    command, *args = ARGV
    case command
    when "push"
      name = File.basename(args.first)
      File.open(File.join(state, "calls.log"), "a") { |f| f.puts "push #{name}" }
      mode = File.read(File.join(state, "#{name}.push")).strip
      case mode
      when "ok" then puts "Successfully registered gem: #{name}"
      when "exists" then puts "Pushing gem to https://rubygems.org...\nRepushing of gem versions is not allowed.\nPlease use `gem yank` to remove bad gem releases."; exit 1
      else warn "ERROR:  While executing gem ... (Gem::RubyGemsVersionCheck) #{mode}"; exit 1
      end
    when "fetch"
      File.open(File.join(state, "calls.log"), "a") { |f| f.puts args.join(" ") }
      platform = args.include?("--platform") ? "-#{args[args.index('--platform') + 1]}" : ""
      name = "emf-#{args[args.index('--version') + 1]}#{platform}.gem"
      remote = File.join(state, "#{name}.remote")
      abort "ERROR:  Could not find a valid gem 'emf'" unless File.exist?(remote)
      File.write(name, File.read(remote))
      puts "Downloaded #{name.delete_suffix('.gem')}"
    end
  RUBY

  before do
    @tmp = Dir.mktmpdir("emf-publish-spec")
    @state = File.join(@tmp, "state")
    @gems = File.join(@tmp, "gems")
    @tools = File.join(@tmp, "bin")
    [@state, @gems, @tools].each { |dir| FileUtils.mkdir_p(dir) }
    File.write(File.join(@tools, "gem"), fake_gem)
    File.chmod(0o755, File.join(@tools, "gem"))
  end

  after { FileUtils.rm_rf(@tmp) }

  def add_gem(name, push:, remote: nil)
    File.write(File.join(@gems, name), "local bytes of #{name}")
    File.write(File.join(@state, "#{name}.push"), push)
    File.write(File.join(@state, "#{name}.remote"), remote) if remote
  end

  def publish
    env = { "PATH" => "#{@tools}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}", "FAKE_GEM_STATE" => @state }
    out, err, status = Open3.capture3(env, RbConfig.ruby, File.join(root, "script/publish_release_gems"), "--directory", @gems)
    [status.exitstatus, out, err]
  end

  def calls = File.read(File.join(@state, "calls.log")).lines.map(&:strip)

  it "pushes every gem when all versions are new" do
    add_gem("emf-1.0.0.gem", push: "ok")
    add_gem("emf-1.0.0-arm64-darwin.gem", push: "ok")
    status, out, = publish
    expect(status).to eq(0)
    expect(out).to include("pushed emf-1.0.0.gem", "pushed emf-1.0.0-arm64-darwin.gem", "published 2 gems")
    expect(calls).to eq(["push emf-1.0.0-arm64-darwin.gem", "push emf-1.0.0.gem"])
  end

  it "continues and reports a gem already published with identical bytes" do
    add_gem("emf-1.0.0-arm64-darwin.gem", push: "exists", remote: "local bytes of emf-1.0.0-arm64-darwin.gem")
    add_gem("emf-1.0.0.gem", push: "ok")
    status, out, = publish
    expect(status).to eq(0)
    expect(out).to include("already published, identical: emf-1.0.0-arm64-darwin.gem", "pushed emf-1.0.0.gem")
    expect(calls).to include("emf --version 1.0.0 --prerelease --platform arm64-darwin")
  end

  it "fetches the source gem without a platform" do
    add_gem("emf-1.0.0.gem", push: "exists", remote: "local bytes of emf-1.0.0.gem")
    status, = publish
    expect(status).to eq(0)
    expect(calls).to include("emf --version 1.0.0 --prerelease")
  end

  it "fails when the published gem has different bytes" do
    add_gem("emf-1.0.0-arm64-darwin.gem", push: "exists", remote: "someone else's bytes")
    add_gem("emf-1.0.0.gem", push: "ok")
    status, _out, err = publish
    expect(status).to eq(1)
    expect(err).to match(/emf-1\.0\.0-arm64-darwin\.gem is already published with different bytes/)
    expect(calls).not_to include("push emf-1.0.0.gem")
  end

  it "fails when the published gem cannot be fetched back" do
    add_gem("emf-1.0.0.gem", push: "exists")
    status, _out, err = publish
    expect(status).to eq(1)
    expect(err).to match(/already published but could not be fetched back/)
  end

  it "fails on any other push error" do
    add_gem("emf-1.0.0.gem", push: "network down")
    status, _out, err = publish
    expect(status).to eq(1)
    expect(err).to match(/gem push emf-1\.0\.0\.gem failed:.*network down/m)
    expect(calls).to eq(["push emf-1.0.0.gem"])
  end

  it "stops at the first failure and reports what was already published" do
    add_gem("emf-1.0.0-arm64-darwin.gem", push: "ok")
    add_gem("emf-1.0.0-x86_64-linux-gnu.gem", push: "boom")
    add_gem("emf-1.0.0.gem", push: "ok")
    status, out, err = publish
    expect(status).to eq(1)
    expect(out).to include("pushed emf-1.0.0-arm64-darwin.gem")
    expect(err).to include("published or already identical before the failure: emf-1.0.0-arm64-darwin.gem")
    expect(calls).to eq(["push emf-1.0.0-arm64-darwin.gem", "push emf-1.0.0-x86_64-linux-gnu.gem"])
  end

  it "fails on an empty directory" do
    status, _out, err = publish
    expect(status).to eq(1)
    expect(err).to include("no gems found")
  end

  it "is the only thing the workflow's publish job pushes with, and no step overrides a GITHUB_ variable" do
    text = File.read(File.join(root, ".github/workflows/release.yml"))
    steps = YAML.safe_load(text).dig("jobs", "publish", "steps")
    expect(steps.filter_map { |step| step["run"] }.join).to include("script/publish_release_gems --directory verified")
    expect(steps.filter_map { |step| step["run"] }.join).not_to match(/gem push/)
    expect(text).not_to match(/^\s+(-e )?GITHUB_\w+[:=]/)
  end
end
