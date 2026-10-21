# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require_relative "process_supervisor"

# Runs each committed WMF resilience seed in a supervised child with the backend forced. A seed passes only when its
# child exits 0 within the wall and RSS limits, reports the expected outcome (parsed or rejected), keeps the source
# bytes through serialize/reparse/serialize for parsed input, and survives a deterministic battery of truncations and
# byte mutations whose every result is a parsed document or an Emf::Error.
module WmfResilience
  SEED_DIR = "emf-rs/fuzz/seeds/wmf-resilience"
  BACKENDS = %w[native ruby].freeze
  FLIPS = [0x00, 0xFF, 0x80, 0x01].freeze

  module_function

  def seed_paths(root)
    Dir.glob(File.join(root, SEED_DIR, "*.wmf")).map { |path| path.delete_prefix("#{root}/") }
  end

  # Parsed means a document that serializes back to the input; rejected means an Emf::Error. Nothing else is defined.
  def classify(bytes)
    require "emf"
    document = Emf.parse(bytes)
    again = Emf.serialize(Emf.parse(Emf.serialize(document)))
    { "outcome" => "parsed", "round_trip" => Emf.serialize(document) == bytes && again == bytes ? "ok" : "bytes_changed" }
  rescue Emf::Native::Unavailable => e
    # An Emf::Error subclass, but a missing library is a setup failure, never a verdict on the bytes.
    { "outcome" => "undefined", "exception" => e.class.name }
  rescue Emf::Error => e
    { "outcome" => "rejected", "exception" => e.class.name }
  rescue StandardError, NotImplementedError => e
    { "outcome" => "undefined", "exception" => e.class.name, "message" => e.message.byteslice(0, 256) }
  end

  def observe(path)
    bytes = File.binread(path)
    base = classify(bytes)
    mutations = mutate(bytes).map { |label, mutated| [label, classify(mutated)] }
    bad = mutations.reject { |_label, result| defined_result?(result) }
    base.merge("mutations" => mutations.size, "undefined" => bad.first(5).map { |label, result| { "mutation" => label }.merge(result) })
  end

  def defined_result?(result)
    result["outcome"] == "rejected" || (result["outcome"] == "parsed" && result["round_trip"] == "ok")
  end

  def mutate(bytes)
    truncations = (0...bytes.bytesize).map { |length| ["truncate-#{length}", bytes.byteslice(0, length)] }
    flips = (0...bytes.bytesize).flat_map do |offset|
      FLIPS.map { |value| ["set-#{offset}-#{value}", with_byte(bytes, offset, value)] }
    end
    truncations + flips + [["trailing-garbage", bytes + ("\xFF".b * 64)]]
  end

  def with_byte(bytes, offset, value)
    copy = bytes.b
    copy.setbyte(offset, value)
    copy
  end

  class Runner
    def initialize(root:, backend:, wall_seconds:, rss_limit_bytes:)
      raise ArgumentError, "backend must be one of #{BACKENDS.join(', ')}" unless BACKENDS.include?(backend)

      @root = root
      @backend = backend
      @supervisor = ProcessSupervisor.new(wall_seconds: wall_seconds, rss_limit_bytes: rss_limit_bytes)
    end

    def call(paths)
      paths.map { |path| verdict(path) }
    end

    private

    def verdict(path)
      file = File.join(@root, path)
      before = Digest::SHA256.file(file).hexdigest
      result = @supervisor.call([RbConfig.ruby, "-I", File.join(@root, "lib"), __FILE__, "--observe", file],
                                env: { "EMF_BACKEND" => @backend })
      { "path" => path, "status" => result.status.to_s, "exit_code" => result.exit_code, "signal" => result.signal,
        "elapsed_seconds" => result.elapsed.round(3), "peak_rss_bytes" => result.peak_rss_bytes,
        "unchanged" => before == Digest::SHA256.file(file).hexdigest, "observation" => observation(result) }
    end

    def observation(result)
      return {} unless result.success?

      parsed = JSON.parse(result.output.lines.map(&:strip).reject(&:empty?).last.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.shift == "--observe"
  output = $stdout.dup
  $stdout.reopen(File::NULL, "w")
  $stderr.reopen(File::NULL, "w")
  output.write(JSON.generate(WmfResilience.observe(ARGV.fetch(0))))
  output.close
end
