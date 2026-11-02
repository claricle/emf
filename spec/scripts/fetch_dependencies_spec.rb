# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"
require "rbconfig"
require "uri"
require "zlib"
require_relative "../../script/platform_probe/fetch_dependencies"

RSpec.describe PlatformProbeDependencies do
  around do |example|
    Dir.mktmpdir("emf-fetch-dependencies") do |directory|
      @directory = directory
      @stage = File.join(directory, "stage")
      FileUtils.mkdir_p(@stage)
      example.run
    end
  end

  def package(name, directory: @directory, platform: "ruby")
    spec = Gem::Specification.new do |gem|
      gem.name = name
      gem.version = "1.0.0"
      gem.summary = "Dependency staging fixture"
      gem.authors = ["Test"]
      gem.platform = platform
      yield gem if block_given?
    end
    path = File.join(directory, "#{spec.full_name}.gem")
    Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec, true, false, path) }
    Gem::Source::SpecificFile.new(path)
  end

  it "stages direct, transitive and platform-only runtime dependencies for an offline install" do
    direct = package("staging-direct") { |gem| gem.add_dependency "staging-transitive", "~> 1.0" }
    transitive = package("staging-transitive")
    platform = package("staging-platform")
    package("emf", directory: @stage) do |gem|
      gem.add_dependency "staging-direct", "~> 1.0"
      gem.add_development_dependency "not-a-runtime-dependency"
    end
    package("emf", directory: @stage, platform: Gem::Platform.local.to_s) do |gem|
      gem.add_dependency "staging-direct", "~> 1.0"
      gem.add_dependency "staging-platform", "~> 1.0"
    end

    # Exercise RubyGems' real resolver and downloads against local packages.
    # No network, globally installed gems, or fake dependency graph results.
    resolver = Gem::Resolver::InstallerSet.new(:local)
    resolver.ignore_installed = true
    [direct, transitive, platform].each { |source| resolver.add_local(source.spec.name, source.spec, source) }
    allow(Gem::Resolver::BestSet).to receive(:new).and_return(resolver)

    described_class.fetch(@stage)

    names = Dir.glob(File.join(@stage, "staging-*.gem")).map { |path| Gem::Package.new(path).spec.name }
    expect(names).to contain_exactly("staging-direct", "staging-transitive", "staging-platform")
  end

  it "fails when no emf package was staged" do
    expect { described_class.fetch(@stage) }.to raise_error(ArgumentError, /no emf packages/)
  end

  def repository(sources)
    directory = File.join(@directory, "repository")
    quick = File.join(directory, "quick", "Marshal.4.8")
    FileUtils.mkdir_p([quick, File.join(directory, "gems")])
    sources.each do |source|
      spec = source.spec
      FileUtils.cp(source.path, File.join(directory, "gems"))
      File.binwrite(File.join(quick, "#{spec.full_name}.gemspec.rz"), Gem.deflate(Marshal.dump(spec)))
    end
    tuples = sources.map { |source| [source.spec.name, source.spec.version, source.spec.platform.to_s] }.sort
    { "specs" => tuples, "latest_specs" => tuples, "prerelease_specs" => [] }.each do |name, entries|
      Zlib::GzipWriter.open(File.join(directory, "#{name}.4.8.gz")) { |file| file.write(Marshal.dump(entries)) }
    end
    URI::Generic.build(scheme: "file", path: URI::RFC2396_Parser.new.escape("/#{directory.delete_prefix('/')}")).to_s
  end

  it "resolves and downloads with the default resolver in a fresh Ruby process" do
    direct = package("staging-direct") { |gem| gem.add_dependency "staging-transitive", "~> 1.0" }
    transitive = package("staging-transitive")
    package("emf", directory: @stage) { |gem| gem.add_dependency "staging-direct", "~> 1.0" }
    source = repository([direct, transitive])
    script = File.expand_path("../../script/platform_probe/fetch_dependencies.rb", __dir__)
    environment = { "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil,
                    "GEM_SPEC_CACHE" => File.join(@directory, "spec-cache") }
    harness = <<~RUBY
      repository, script, directory = ARGV
      require script
      require "uri"
      # Only replace network transport; retain the HTTPS source selection,
      # default resolver and package downloader used by the standalone script.
      fetcher = Gem::RemoteFetcher.fetcher
      fetcher.define_singleton_method(:fetch_path) do |uri, *arguments|
        local = URI.parse(repository + URI.parse(uri.to_s).path)
        super(local, *arguments)
      end
      Gem.sources = ["https://dependency-fixture.invalid/"]
      PlatformProbeDependencies.fetch(directory)
    RUBY

    out, err, status = Open3.capture3(environment, RbConfig.ruby, "-e", harness, source, script, @stage)

    expect(status.success?).to be(true), "#{out}\n#{err}"
    names = Dir.glob(File.join(@stage, "staging-*.gem")).map { |path| Gem::Package.new(path).spec.name }
    expect(names).to contain_exactly("staging-direct", "staging-transitive")
  end
end
