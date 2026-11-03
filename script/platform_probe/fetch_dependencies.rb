# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "rubygems/remote_fetcher"
require "rubygems/request_set"
require "tmpdir"

module PlatformProbeDependencies
  module_function

  # Resolve from the built packages, including platform-only dependencies, and
  # download the complete runtime graph before entering the offline install.
  def fetch(directory)
    packages = Dir.glob(File.join(directory, "emf-*.gem"))
    raise ArgumentError, "no emf packages in #{directory}" if packages.empty?

    dependencies = packages.flat_map { |path| Gem::Package.new(path).spec.runtime_dependencies }
    requests = Gem::RequestSet.new(*dependencies)
    requests.resolve
    Dir.mktmpdir("emf-dependency-cache") do |cache|
      requests.sorted_requests.each do |request|
        FileUtils.cp(request.download(cache), directory)
      end
    end
  end
end

PlatformProbeDependencies.fetch(File.expand_path(ARGV.fetch(0))) if $PROGRAM_NAME == __FILE__
