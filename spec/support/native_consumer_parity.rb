# frozen_string_literal: true

require "json"
require "rbconfig"
require "tmpdir"
require_relative "process_supervisor"

module NativeConsumerParity
  FIXTURES = %w[emf/test-007.emf wmf/standard-line.wmf wmf/placeable-line.wmf].freeze
  BACKENDS = %w[ruby native].freeze
  COMMANDS = %w[info dump stats validate round-trip].freeze
  ROOT = File.expand_path("../..", __dir__)
  CHILD = <<~SCRIPT
    require "json"
    require "emf"
    report, action, *arguments = ARGV
    selected = Emf::Backend.send(:selected)
    evidence = { backend: selected.is_a?(Module) ? selected.name : selected.class.name, native_calls: 0, ruby_calls: 0 }
    if ENV.fetch("EMF_BACKEND") == "native"
      probe = Module.new do
        define_method(:parse) do |bytes|
          evidence[:native_calls] += 1
          super(bytes)
        end
      end
      Emf::Native::Adapter.prepend(probe)
    end
    [Emf::Emr::Parser, Emf::Wmf::Parser].each do |parser|
      probe = Module.new do
        define_method(:call) do |bytes, **options|
          evidence[:ruby_calls] += 1
          raise "forced native invoked Ruby parser" if ENV.fetch("EMF_BACKEND") == "native"
          super(bytes, **options)
        end
      end
      parser.singleton_class.prepend(probe)
    end
    at_exit do
      error = $!
      evidence[:error] = [error.class.name, error.message] if error && !error.is_a?(SystemExit)
      File.write(report, JSON.generate(evidence))
    end
    if action == "cli"
      ARGV.replace(arguments)
      load File.expand_path("exe/emf")
    else
      metafile = Emf.parse_file(arguments.fetch(0))
      stats = Emf::Visitors::Stats.new.visit_all(metafile)
      dump = Emf::Visitors::Dump.new.visit_all(metafile)
      puts JSON.generate(total: stats.total, histogram: stats.histogram, stats: stats.to_s,
                         lines: dump.lines, dump: dump.to_s, records: metafile.records.size,
                         errors: metafile.errors.map(&:message))
    end
  SCRIPT

  module_function

  def library
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.join(ROOT, "emf-rs/target/debug/libemf_ffi.#{extension}")
    end
  end

  def fixture(path)
    File.join(ROOT, "spec/fixtures", path)
  end

  def run(backend, action, *arguments)
    Dir.mktmpdir("emf-consumer-") do |directory|
      report = File.join(directory, "report.json")
      command = [RbConfig.ruby, "-W0", "-Ilib", "-e", CHILD, report, action, *arguments]
      result = ProcessSupervisor.new(wall_seconds: 20, rss_limit_bytes: 512 * 1024 * 1024).call(
        command, env: { "EMF_BACKEND" => backend, "EMF_NATIVE_LIBRARY" => library }
      )
      raise "consumer child #{result.to_h.inspect}" unless result.status == :exited && File.file?(report)

      { "exit" => result.exit_code, "output" => result.output, "evidence" => JSON.parse(File.read(report)) }
    end
  end
end
