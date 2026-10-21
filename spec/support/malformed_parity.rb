# frozen_string_literal: true

require "json"
require "digest"
require "rbconfig"
require "tmpdir"
require_relative "backend_parity"
require_relative "process_supervisor"

# Compares what the Ruby and native backends do with each corrupt fixture. Each
# backend runs in its own supervised child and reports a compact observation:
# outcome, record list (class, offset, wire digest), diagnostics, trailing bytes
# and the serialization digest.
module MalformedParity
  LIMITS = { wall_seconds: 60, rss_limit_bytes: 2048 * 1024 * 1024 }.freeze

  module_function

  def entries(manifest)
    manifest.fetch("fixtures").select { |entry| entry.fetch("path").start_with?("spec/fixtures/emf-corrupted/") }
  end

  def observe(bytes)
    metafile = Emf.parse(bytes)
    wire = BackendParity::WireWalker.new
    out = Emf.serialize(metafile)
    { "outcome" => metafile.errors? ? "recovered" : "parsed", "format" => metafile.format.to_s,
      "records" => metafile.records.map { |record| record_fields(record, wire) },
      "errors" => metafile.errors.map { |e| error_fields(e) },
      "trailing" => BackendParity.binary(metafile.trailing), "emf_plus" => emf_plus(metafile),
      "serialized" => { "size" => out.bytesize, "sha256" => Digest::SHA256.hexdigest(out), "equals_input" => out == bytes } }
  rescue Emf::FormatError => e
    { "outcome" => "format_error", "error" => { "class" => e.class.name, "message" => e.message } }
  end

  def emf_plus(metafile)
    metafile.emf_plus.is_a?(String) ? BackendParity.binary(metafile.emf_plus) : metafile.emf_plus
  end

  def record_fields(record, wire)
    fields = { "class" => record.class.name, "type_id" => record.type_id.to_i, "offset" => record.offset }
    fields["wire_class"] = record.wire.class.name
    fields["wire_sha256"] = BackendParity.digest(BackendParity.capture { wire.call(record.wire) })
    fields
  end

  def error_fields(error)
    { "class" => error.class.name, "offset" => error.offset, "record_code" => error.record_code, "message" => error.message }
  end

  class Runner
    def initialize(root:, library:)
      @root = root
      @library = library
      @supervisor = ProcessSupervisor.new(**LIMITS)
    end

    CHILD = File.join(__dir__, "malformed_parity_child.rb")

    # The observation crosses via a file: the supervisor caps pipe output.
    def call(path, backend)
      Dir.mktmpdir("emf-malformed-parity") do |directory|
        target = File.join(directory, "observation.json")
        command = [RbConfig.ruby, "-I", File.join(@root, "lib"), CHILD, path, backend, target]
        result = @supervisor.call(command, env: { "EMF_NATIVE_LIBRARY" => @library })
        raise "#{backend} child #{result.status} exit=#{result.exit_code}: #{result.output}" unless result.success?

        JSON.parse(File.read(target))
      end
    end
  end
end
