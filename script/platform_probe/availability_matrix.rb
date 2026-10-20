# frozen_string_literal: true

# Usage: GEM_HOME=HOME ruby availability_matrix.rb --library PATH --fixture PATH
#
# Runs the emf gem installed in GEM_HOME (never the checkout) under every
# combination of a broken native library and a backend mode, each in a child
# process whose PATH holds only the ruby binary. Prints a case x mode table and
# exits 1 when a row differs from the contract:
#   auto   : availability failures fall back to the Ruby backend silently;
#   native : the same failures raise Emf::Native::Unavailable naming the cause;
#   either : malformed input reaches the native parser and is never re-parsed
#            by Ruby.
# Rows with a nil library run with no EMF_NATIVE_LIBRARY, so the installed
# gem's own platforms.json discovery is exercised; the "broken_install" rows
# damage a private copy of GEM_HOME's manifest or bundled library.
# Fixture libraries are derived from --library (truncation, a patched header
# for the wrong architecture) or compiled with cc when one is on this script's
# PATH (wrong ABI, missing dependent library); rows needing cc are skipped
# without one.

require "fileutils"
require "json"
require "open3"
require "optparse"
require "rbconfig"
require "tmpdir"

module AvailabilityMatrix
  CLEAN_ENV = %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP GEM_HOME GEM_PATH
                 EMF_BACKEND EMF_NATIVE_LIBRARY].to_h { |k| [k, nil] }.freeze
  MODES = %w[auto native].freeze
  SYMBOLS = %w[emf_parse emf_document_snapshot emf_record_bytes emf_buffer_view emf_error_view].freeze

  CHILD = <<~RUBY
    require "json"
    ruby_called = false
    require "emf"
    ruby = Emf::Backend.const_get(:Ruby)
    ruby.singleton_class.prepend(Module.new { define_method(:parse) { |bytes| ruby_called = true; super(bytes) } })
    result = { "ruby_called" => false }
    begin
      Emf.parse(File.binread(ARGV.fetch(0)))
    rescue Exception => e # rubocop:disable Lint/RescueException
      result.merge!("error_class" => e.class.name, "message" => e.message)
    end
    result["ruby_called"] = ruby_called
    result["gem_dir"] = Gem.loaded_specs.fetch("emf").gem_dir
    puts JSON.generate(result)
  RUBY

  Row = Struct.new(:name, :mode, :backend, :error_class, :message, keyword_init: true)

  # Builds the broken libraries; every method returns a path or nil (skipped).
  class Fixtures
    def initialize(directory, library)
      @directory = directory
      @library = library
      @extension = File.extname(library)
    end

    def path(name) = File.join(@directory, "#{name}#{@extension}")

    def truncated
      File.binwrite(path("corrupt"), File.binread(@library)[0, File.size(@library) / 2])
      path("corrupt")
    end

    def foreign_architecture
      File.binwrite(path("foreign"), swap_machine(File.binread(@library)))
      path("foreign")
    end

    def wrong_abi
      compile("wrong_abi", stub_source(999))
    end

    def missing_dependency
      dependency = compile("dependency", "int emf_dependency(void) { return 1; }\n")
      stub = compile("needs_dependency", "extern int emf_dependency(void);\n#{stub_source('emf_dependency()')}", dependency)
      File.delete(dependency) if stub
      stub
    end

    private

    def stub_source(abi)
      functions = SYMBOLS.map { |name| "int #{name}(void) { return 0; }" }
      (["int emf_abi_version(void) { return #{abi}; }"] + functions + ["void emf_document_free(void *p) {}",
                                                                       "void emf_buffer_free(void *p) {}",
                                                                       "void emf_error_free(void *p) {}"]).join("\n") << "\n"
    end

    def compile(name, source, *libraries)
      return unless compiler && !Gem.win_platform?

      File.write(File.join(@directory, "#{name}.c"), source)
      out = path(name)
      _o, status = Open3.capture2e(compiler, "-shared", "-fPIC", "-o", out, File.join(@directory, "#{name}.c"), *libraries)
      status.success? ? out : raise("#{compiler} failed to build #{name}")
    end

    def compiler
      @compiler ||= %w[cc clang gcc].find do |tool|
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, tool)) }
      end
    end

    # Rewrites the machine field of the object header to the other of
    # x86_64/arm64, so dlopen rejects the otherwise intact library.
    def swap_machine(bytes)
      bytes = bytes.dup
      case bytes[0, 4]
      when "\x7FELF".b then bytes[18, 2] = [bytes[18, 2].unpack1("v") == 62 ? 183 : 62].pack("v")
      when "\xCF\xFA\xED\xFE".b then bytes[4, 4] = [bytes[4, 4].unpack1("V") == 0x0100000C ? 0x01000007 : 0x0100000C].pack("V")
      when /\AMZ/n then swap_pe(bytes)
      else raise "cannot derive a foreign-architecture library from #{@library}: unknown object format"
      end
      bytes
    end

    def swap_pe(bytes)
      offset = bytes[0x3C, 4].unpack1("V") + 4
      bytes[offset, 2] = [bytes[offset, 2].unpack1("v") == 0x8664 ? 0xAA64 : 0x8664].pack("v")
    end
  end

  # One case: which library, whether Fiddle is hidden, which input, and the
  # expectation for each mode. An expectation is [backend, error_class, message pattern].
  Scenario = Struct.new(:name, :library, :hide_fiddle, :input, :auto, :native, :gem_home, keyword_init: true)

  class Runner
    def initialize(gem_home:, library:, fixture:, directory:)
      @gem_home = gem_home
      @library = library
      @fixture = fixture
      @directory = directory
      @fixtures = Fixtures.new(directory, library)
      @ruby = RbConfig.ruby
    end

    def scenarios
      unavailable = ->(pattern) { ["none", "Emf::Native::Unavailable", pattern] }
      load_failure = ->(path) { unavailable.call(/native backend could not load: .*#{Regexp.escape(File.basename(path))}/m) }
      [baseline, absent(load_failure), broken("corrupt_library", @fixtures.truncated, load_failure),
       broken("wrong_architecture", @fixtures.foreign_architecture, load_failure),
       dependent(load_failure), wrong_abi(unavailable), missing_fiddle(unavailable),
       *malformed_inputs, discovered, *broken_installs(unavailable)].compact
    end

    def run(scenario, mode)
      home = scenario.gem_home || @gem_home
      env = CLEAN_ENV.merge("GEM_HOME" => home, "GEM_PATH" => home, "PATH" => File.dirname(@ruby),
                            "EMF_BACKEND" => mode, "EMF_NATIVE_LIBRARY" => scenario.library)
      out, err, status = Open3.capture3(env, @ruby, *flags(scenario), "-e", CHILD, scenario.input, chdir: @directory)
      raise "#{scenario.name}/#{mode} child failed: #{err}#{out}" unless status.success?

      observed(scenario, mode, JSON.parse(out.lines.last), home)
    end

    private

    def flags(scenario)
      return [] unless scenario.hide_fiddle

      shim = File.join(@directory, "no_fiddle")
      FileUtils.mkdir_p(shim)
      File.write(File.join(shim, "fiddle.rb"), "raise LoadError, 'cannot load such file -- fiddle (hidden)'\n")
      ["-I", shim]
    end

    def observed(scenario, mode, report, home)
      raise "emf resolved outside GEM_HOME: #{report['gem_dir']}" unless report["gem_dir"].start_with?(File.realpath(home))

      backend = if report["ruby_called"] then "ruby"
                elsif report["error_class"] == "Emf::Native::Unavailable" then "none"
                else "native"
                end
      Row.new(name: scenario.name, mode: mode, backend: backend, error_class: report["error_class"], message: report["message"])
    end

    def scenario(name, library, auto:, native:, **rest)
      Scenario.new(name: name, library: library, input: @fixture, auto: auto, native: native, **rest)
    end

    def fallback = ["ruby", nil, nil]

    def baseline = scenario("working_library", @library, auto: ["native", nil, nil], native: ["native", nil, nil])

    def absent(load_failure)
      path = File.join(@directory, "absent#{File.extname(@library)}")
      scenario("missing_library", path, auto: fallback, native: load_failure.call(path))
    end

    def broken(name, path, load_failure) = scenario(name, path, auto: fallback, native: load_failure.call(path))

    def dependent(load_failure)
      path = @fixtures.missing_dependency
      path && scenario("missing_dependent_library", path, auto: fallback, native: load_failure.call(path))
    end

    def wrong_abi(unavailable)
      path = @fixtures.wrong_abi
      path && scenario("wrong_abi_version", path, auto: fallback, native: unavailable.call(/ABI version mismatch \(expected 1\)/))
    end

    def missing_fiddle(unavailable)
      scenario("missing_fiddle", @library, hide_fiddle: true, auto: fallback,
                                           native: unavailable.call(/dependencies could not load: .*fiddle/))
    end

    def malformed_inputs
      { "malformed_garbage" => "not an emf file at all", "malformed_truncated" => File.binread(@fixture)[0, 60] }.map do |name, bytes|
        path = File.join(@directory, "#{name}.bin")
        File.binwrite(path, bytes)
        error = ["native", "Emf::FormatError", /./]
        scenario(name, @library, input: path, auto: error, native: error)
      end
    end

    def discovered
      scenario("library_not_configured", nil, auto: ["native", nil, nil], native: ["native", nil, nil])
    end

    def broken_installs(unavailable)
      {
        "installed_checksum_mismatch" => [->(dir) { edit_manifest(dir, "sha256" => "0" * 64) }, /library checksum mismatch/],
        "installed_abi_mismatch" => [->(dir) { edit_manifest(dir, "abi_version" => 2) }, /manifest ABI version mismatch \(expected 1\)/],
        "installed_platform_mismatch" => [->(dir) { edit_manifest(dir, "platform" => "x86_64-nonexistent_os") },
                                          /manifest platform mismatch/],
        "installed_library_missing" => [->(dir) { FileUtils.rm(bundled_library(dir)) }, /manifest could not load: .*No such file/]
      }.map do |name, (damage, pattern)|
        scenario(name, nil, gem_home: damaged_home(name, damage), auto: fallback, native: unavailable.call(pattern))
      end
    end

    def damaged_home(name, damage)
      home = File.join(@directory, "homes", name)
      FileUtils.mkdir_p(File.dirname(home))
      FileUtils.cp_r(@gem_home, home)
      damage.call(File.join(Dir.glob(File.join(home, "gems", "emf-*")).fetch(0), "lib/emf/native"))
      home
    end

    def edit_manifest(dir, changes)
      path = File.join(dir, "platforms.json")
      File.write(path, JSON.generate(JSON.parse(File.read(path)).merge(changes)))
    end

    def bundled_library(dir)
      manifest = JSON.parse(File.read(File.join(dir, "platforms.json")))
      File.join(dir, manifest.fetch("platform"), manifest.fetch("library"))
    end
  end

  class Report
    def initialize(runner)
      @runner = runner
      @mismatches = []
    end

    def call
      rows = @runner.scenarios.flat_map { |scenario| MODES.map { |mode| check(scenario, mode) } }
      print_table(rows)
      @mismatches.each { |line| warn "MISMATCH #{line}" }
      @mismatches.empty?
    end

    private

    def check(scenario, mode)
      row = @runner.run(scenario, mode)
      backend, error_class, pattern = scenario.public_send(mode.to_sym)
      problems = []
      problems << "backend #{row.backend}, expected #{backend}" unless row.backend == backend
      problems << "error #{row.error_class.inspect}, expected #{error_class.inspect}" unless row.error_class == error_class
      problems << "message #{row.message.inspect} !~ #{pattern.inspect}" if pattern && !row.message.to_s.match?(pattern)
      @mismatches << "#{row.name}/#{mode}: #{problems.join('; ')}" unless problems.empty?
      row
    end

    def summary(row)
      return "" unless row.error_class

      "#{row.error_class}: #{row.message.lines.first.strip[0, 140]}"
    end

    def print_table(rows)
      puts line("case", "mode", "backend", "error")
      rows.each { |r| puts line(r.name, r.mode, r.backend, summary(r)) }
      puts(rows.map { |r| "availability #{r.name}/#{r.mode}=#{r.backend}#{" #{r.error_class}" if r.error_class}" })
    end

    def line(*cells) = cells.zip([27, 7, 8, 0]).map { |cell, width| cell.ljust(width) }.join(" ").rstrip
  end
end

options = {}
OptionParser.new do |o|
  o.on("--library PATH") { |v| options[:library] = File.expand_path(v) }
  o.on("--fixture PATH") { |v| options[:fixture] = File.expand_path(v) }
end.parse!
gem_home = ENV.fetch("GEM_HOME", nil) or abort "GEM_HOME must point at the install under test"
abort "--library and --fixture are required" unless options[:library] && options[:fixture]

passed = Dir.mktmpdir("emf-availability") do |directory|
  runner = AvailabilityMatrix::Runner.new(gem_home: gem_home, library: options[:library], fixture: options[:fixture], directory: directory)
  AvailabilityMatrix::Report.new(runner).call
end
puts(passed ? "availability matrix passed" : "availability matrix FAILED")
exit(passed ? 0 : 1)
