# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
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
end
