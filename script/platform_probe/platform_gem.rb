# frozen_string_literal: true

# Usage: ruby platform_gem.rb LIBRARY INTENDED_PLATFORM
#
# Builds a throwaway platform gem (emf-platform-probe 0.0.0, never published)
# plus a "ruby" decoy of the same version in a temp dir, installs by name with
# `gem install --local` into an isolated GEM_HOME, and runs load.rb against the
# installed library. Prints two JSON lines (resolution, then load.rb's line).
# Exits non-zero when the intended platform is not the one RubyGems installed.

require "json"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "fileutils"
require "open3"

module PlatformGemProbe
  NAME = "emf-platform-probe"
  CLEAN_ENV = %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP GEM_HOME GEM_PATH].to_h { |k| [k, nil] }.freeze
  VERSION = "0.0.0"

  module_function

  def spec(platform, files)
    Gem::Specification.new do |s|
      s.name = NAME
      s.version = VERSION
      s.summary = "Throwaway platform resolution probe; never published"
      s.authors = ["emf platform probe"]
      s.license = "BSD-2-Clause"
      s.platform = platform
      s.files = files
    end
  end

  def build(dir, platform, library)
    Dir.chdir(dir) do
      files = []
      if library
        target = File.join("lib", "emf_platform_probe", File.basename(library))
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(library, target)
        files << target
      else
        FileUtils.mkdir_p("lib")
        File.write("lib/emf_platform_probe.rb", "# decoy\n")
        files << "lib/emf_platform_probe.rb"
      end
      Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec(platform, files), true) }
    end
  end

  def install(gem_dir, gem_home)
    env = CLEAN_ENV.merge("GEM_HOME" => gem_home, "GEM_PATH" => gem_home)
    cmd = [RbConfig.ruby, "-rrubygems/gem_runner", "-e", "Gem::GemRunner.new.run(ARGV)",
           "install", NAME, "--version", VERSION, "--local", "--no-document", "--ignore-dependencies"]
    out, status = Open3.capture2e(env, *cmd, chdir: gem_dir)
    [out, status.success?]
  end

  def installed_spec(gem_home)
    Dir.glob(File.join(gem_home, "specifications", "#{NAME}-*.gemspec")).filter_map do |path|
      Gem::Specification.load(path)
    end.first
  end

  def resolve(library, intended)
    Dir.mktmpdir("emf-platform-probe") do |tmp|
      gem_dir = File.join(tmp, "gems").tap { |d| FileUtils.mkdir_p(d) }
      gem_home = File.join(tmp, "home")
      stage(tmp, gem_dir, library, intended)
      out, ok = install(gem_dir, gem_home)
      result = finish(installed_spec(gem_home), intended, ok, out.lines.last(3).join.strip)
      puts JSON.generate(result)
      ok && result[:native_gem_selected] && installed_library_loads?(result[:installed_library], intended)
    end
  end

  def installed_library_loads?(library, intended)
    out, status = Open3.capture2(CLEAN_ENV, RbConfig.ruby, File.join(__dir__, "load.rb"), library, intended)
    puts out
    status.success?
  end

  def stage(tmp, gem_dir, library, intended)
    [[Gem::Platform::RUBY, nil, "ruby"], [intended, library, "native"]].each do |platform, lib, label|
      work = File.join(tmp, "stage-#{label}").tap { |d| FileUtils.mkdir_p(d) }
      built = build(work, platform, lib)
      FileUtils.mv(File.join(work, built), gem_dir)
    end
  end

  def finish(spec, intended, install_ok, log)
    result = { step: "gem_resolution", rubygems_version: Gem::VERSION, intended_platform: intended,
               gem_install_ok: install_ok, installed_platform: spec&.platform.to_s, install_log_tail: log }
    return result.merge(native_gem_selected: false) unless spec

    library = Dir.glob(File.join(spec.full_gem_path, "lib", "emf_platform_probe", "*")).first
    result.merge(native_gem_selected: !library.nil?, installed_library: library && File.realpath(library))
  end
end

library, intended = ARGV
abort "usage: ruby platform_gem.rb LIBRARY INTENDED_PLATFORM" unless library && intended

exit PlatformGemProbe.resolve(File.expand_path(library), intended) ? 0 : 1
