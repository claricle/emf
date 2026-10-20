# frozen_string_literal: true

require "rbconfig"
require "tmpdir"
require_relative "backend_parity"
require_relative "process_supervisor"

# Acceptance checks use the existing canonical field walker, but require every
# stage to succeed. Each fixture runs in its own bounded process; only a compact
# verdict crosses the pipe, rather than the potentially large observation tree.
module NativeCorpusParity
  VALID_DIRECTORIES = %w[emf emf-ea simple].freeze
  EDITS = {
    "scalar" => [98, ->(wire) { wire.mode = 2 }],
    "nested" => [36, ->(wire) { wire.xform.dx = 12.5 }],
    "array" => [86, ->(wire) { wire.apts[0].x = 241 }],
    "extended_pen" => [95, ->(wire) { wire.width = 17 }],
    "paletted_eof" => [14, ->(wire) { wire.n_size_last = 17 }]
  }.freeze
  EDIT_FIXTURES = {
    "scalar" => "simple/image1.emf",
    "nested" => "simple/image1.emf",
    "array" => "simple/image1.emf",
    "extended_pen" => "emf/test-154.emf",
    "paletted_eof" => "emf/test-165.emf"
  }.freeze

  class Failure < StandardError; end

  # Ruby model scalars retain live BinData primitives; native models store their
  # Ruby values. Compare public values here, leaving wire class/field/bit checks
  # entirely strict in BackendParity::WireWalker.
  class ValueModelWalker < BackendParity::ModelWalker
    def call(node, depth = 0)
      super(node.is_a?(BinData::BasePrimitive) ? node.value : node, depth)
    end
  end

  class ParseSection < BackendParity::ParseSection
    def initialize(source)
      super
      @model = ValueModelWalker.new(@wire)
    end

    private

    # Keep indexed identity and source-byte evidence, and hash every canonical
    # wire field before moving to the next record. Large fixtures must not keep
    # several complete field trees alive across backends and reparses.
    def record(record, index)
      observed = super
      NativeCorpusParity.observable!(observed)
      observed["wire"] = { "canonical_sha256" => BackendParity.digest(observed.fetch("wire")) }
      observed
    end
  end

  module_function

  def entries(manifest)
    manifest.fetch("fixtures").select { |entry| VALID_DIRECTORIES.include?(entry.fetch("path").split("/")[2]) }
  end

  def check(condition, message)
    raise Failure, message unless condition
  end

  def equal(left, right, stage)
    return if left == right

    raise Failure, "#{stage}: #{BackendParity.differences(left, right).join(', ')}"
  end

  def exact(bytes, actual, stage)
    offset = BackendParity.first_difference(bytes, actual)
    check(offset.nil?, "#{stage}: first byte difference #{offset}; sizes #{bytes.bytesize}/#{actual.bytesize}")
  end

  def section(bytes, metafile)
    result = ParseSection.new(bytes).call(metafile)
    check(result.fetch("errors").empty?, "diagnostics: #{result.fetch('errors').inspect}")
    check(result.fetch("records").all? { |record| record.fetch("matches_source") }, "wire differs from source")
    observable!(result)
    result
  end

  def observable!(node)
    case node
    when Hash
      raise Failure, "incomplete canonical field observation: #{node}" if node.key?("unsupported") || node["status"] == "raised"

      node.each_value { |value| observable!(value) }
    when Array
      node.each { |value| observable!(value) }
    end
  end

  def snapshot(bytes, backend)
    ENV["EMF_BACKEND"] = backend
    check(Emf.detect_format(bytes) == :emf, "#{backend} format detection")
    observed = initial_snapshot(bytes, backend)
    GC.start
    equal(observed, section(bytes, Emf.parse(bytes)), "#{backend} reparse")
    GC.start
    observed
  end

  def initial_snapshot(bytes, backend)
    metafile = Emf.parse(bytes)
    exact(bytes, Emf.serialize(metafile), "#{backend} lazy serialization")
    observed = section(bytes, metafile)
    exact(bytes, Emf.serialize(metafile), "#{backend} materialized serialization")
    observed
  end

  def observe(bytes, backend, prefix)
    observed = snapshot(bytes, backend)
    File.write("#{prefix}.json", JSON.generate(observed))
    { "records" => observed.fetch("records").size, "model_sha256" => BackendParity.digest(observed) }
  end

  def edited(bytes, backend, shape)
    ENV["EMF_BACKEND"] = backend
    metafile = Emf.parse(bytes)
    type_id, mutate = EDITS.fetch(shape)
    index = metafile.records.index { |record| record.type_id.to_i == type_id }
    check(!index.nil?, "#{shape}: missing type #{type_id}")
    record = metafile.records.fetch(index)
    original = metafile.records.map { |item| item.wire.to_binary_s }
    header = metafile.header.to_wire.to_binary_s
    independent = Emf.parse(bytes).records.fetch(index)
    check(record == independent && record.eql?(independent) && record.hash == independent.hash, "initial record equality")
    wire = record.wire
    mutate.call(wire)
    check(record.wire.equal?(wire), "live wire identity")
    check(record != independent && !record.eql?(independent), "edit changes record equality")
    output = Emf.serialize(metafile)
    check(output != bytes, "#{shape}: edit did not change serialization")
    exact(output, Emf.serialize(metafile), "stable edited serialization")
    reparsed = Emf.parse(output)
    check(reparsed.records.fetch(index) == record && reparsed.records.fetch(index).hash == record.hash, "edited record reparse")
    exact(header, reparsed.header.to_wire.to_binary_s, "edited header preservation")
    preserve_siblings(original, index, metafile, reparsed)
    observed = section(output, metafile)
    equal(observed, section(output, reparsed), "edited model reparse")
    exact(output, Emf.serialize(reparsed), "edited reserialization")
    [output, observed]
  end

  def preserve_siblings(original, index, metafile, reparsed)
    original.each_with_index do |sibling, sibling_index|
      next if sibling_index == index

      exact(sibling, metafile.records.fetch(sibling_index).wire.to_binary_s, "live sibling #{sibling_index}")
      exact(sibling, reparsed.records.fetch(sibling_index).wire.to_binary_s, "reparsed sibling #{sibling_index}")
    end
  end

  def observe_edit(bytes, shape, backend, prefix)
    output, observed = edited(bytes, backend, shape)
    File.write("#{prefix}.json", JSON.generate(observed))
    File.binwrite("#{prefix}.emf", output)
    { "shape" => shape, "sha256" => Digest::SHA256.hexdigest(output) }
  end

  class Runner
    def initialize(root:, library:)
      @root = root
      @library = library
      @supervisor = ProcessSupervisor.new(wall_seconds: 60, rss_limit_bytes: 2048 * 1024 * 1024)
    end

    def call(path, shape = nil)
      Dir.mktmpdir("emf-native-corpus-parity") do |directory|
        ruby = run_backend(path, shape, "ruby", File.join(directory, "ruby"))
        return ruby if ruby.key?("failure")

        native = run_backend(path, shape, "native", File.join(directory, "native"))
        return native if native.key?("failure")

        compare_observations(directory, shape)
        NativeCorpusParity.equal(ruby, native, "Ruby/native verdict")
        native
      end
    rescue Failure, JSON::ParserError => e
      { "failure" => "#{e.class}: #{e.message}" }
    end

    private

    def compare_observations(directory, shape)
      ruby = JSON.parse(File.read(File.join(directory, "ruby.json")))
      native = JSON.parse(File.read(File.join(directory, "native.json")))
      NativeCorpusParity.equal(ruby, native, "Ruby/native model")
      return unless shape

      NativeCorpusParity.exact(File.binread(File.join(directory, "ruby.emf")),
                               File.binread(File.join(directory, "native.emf")), "Ruby/native edited bytes")
    end

    def run_backend(path, shape, backend, prefix)
      command = [RbConfig.ruby, "-I", File.join(@root, "lib"), __FILE__, "--observe", path, backend, prefix]
      command << shape if shape
      result = @supervisor.call(command, env: { "EMF_NATIVE_LIBRARY" => @library })
      unless result.success?
        failure = "#{backend} child #{result.status} exit=#{result.exit_code} peak_rss=#{result.peak_rss_bytes}: #{result.output}"
        return { "failure" => failure }
      end

      JSON.parse(result.output)
    end
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.shift == "--observe"
  output = $stdout.dup
  $stdout.reopen(File::NULL, "w")
  $stderr.reopen(File::NULL, "w")
  begin
    bytes = File.binread(ARGV.fetch(0))
    backend, prefix, shape = ARGV[1, 3]
    result = if shape
               NativeCorpusParity.observe_edit(bytes, shape, backend, prefix)
             else
               NativeCorpusParity.observe(bytes, backend, prefix)
             end
    output.write(JSON.generate(result))
  rescue StandardError => e
    output.write(JSON.generate("failure" => "#{e.class}: #{e.message.byteslice(0, 4000)}"))
  ensure
    output.close
  end
end
