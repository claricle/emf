# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "rubygems/request_set"

module RuntimeDependencyPackages
  def stage_runtime_dependencies(directory)
    spec = Gem::Specification.load(File.expand_path("../../emf.gemspec", __dir__))
    requests = Gem::RequestSet.new(*spec.runtime_dependencies)
    requests.resolve_current.each do |request|
      dependency = request.full_spec
      if File.file?(dependency.cache_file)
        FileUtils.cp(dependency.cache_file, directory)
      else
        dependency = dependency.dup
        Dir.chdir(dependency.full_gem_path) do
          dependency.files = Dir.glob("**/*").select { |path| File.file?(path) }
          Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
            Gem::Package.build(dependency, true, false, File.join(directory, "#{dependency.full_name}.gem"))
          end
        end
      end
    end
  end
end
