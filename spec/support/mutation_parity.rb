# frozen_string_literal: true

require "json"
require_relative "malformed_parity"

# Deterministic mutation corpus and in-process Ruby/native comparison. Every
# case is a mutated copy of a valid fixture; both backends parse and serialize
# it and the observations (or the raised exception class and message) are compared.
module MutationParity
  SIZE_CAP = 300 * 1024
  SAMPLE = 14
  SEED = 20_261_021
  INTERESTING = [0, 1, 2, 3, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF, 0x0001_0000, 0xFFFF].freeze
  # How many bytes at the start of a record body are treated as count/offset words.
  FIELD_WORDS = 12

  module_function

  def sample(root, manifest)
    paths = manifest.fetch("fixtures").map { |entry| entry.fetch("path") }
    paths = paths.select { |path| path.end_with?(".emf") && !path.include?("emf-corrupted") }
    paths = paths.select { |path| File.size(File.join(root, path)) <= SIZE_CAP }.sort
    small, medium = paths.partition { |path| File.size(File.join(root, path)) < 4096 }
    rng = Random.new(SEED)
    (small.sample(SAMPLE / 2, random: rng) + medium.sample(SAMPLE - (SAMPLE / 2), random: rng)).sort
  end

  def records(bytes)
    out = []
    pos = bytes.byteslice(4, 4).unpack1("V")
    while pos + 8 <= bytes.bytesize
      size = bytes.byteslice(pos + 4, 4).unpack1("V")
      break if size < 8 || pos + size > bytes.bytesize

      out << [pos, size]
      pos += size
    end
    out
  end

  def put(bytes, pos, value)
    copy = bytes.dup
    copy[pos, 4] = [value & 0xFFFF_FFFF].pack("V")
    copy
  end

  # Returns [[label, bytes], ...].
  def cases(bytes, rng)
    large = bytes.bytesize >= 20 * 1024
    build_cases(bytes, rng, large ? 4 : 12, large ? 14 : 40)
  end

  def build_cases(bytes, rng, random, targeted)
    list = []
    random.times do |i|
      copy = bytes.dup
      rng.rand(1..3).times { copy.setbyte(rng.rand(copy.bytesize), rng.rand(256)) }
      list << ["random#{i}", copy]
    end
    list << ["trunc", bytes.byteslice(0, rng.rand(1...bytes.bytesize))]
    list << ["trunc-in-record", bytes.byteslice(0, bytes.bytesize - rng.rand(1..40))]
    list << ["extra-tail", bytes + rng.bytes(rng.rand(1..30))]
    recs = records(bytes)
    return list if recs.empty?

    targeted.times do |i|
      pos, size = recs[rng.rand(recs.size)]
      list << targeted_case(bytes, pos, size, rng, i)
    end
    list
  end

  def targeted_case(bytes, pos, size, rng, index)
    case rng.rand(4)
    when 0 # record head: type
      ["type#{index}@#{pos}", put(bytes, pos, INTERESTING.sample(random: rng) | (rng.rand(2).zero? ? 0 : rng.rand(1..120)))]
    when 1 # nSize just around the layout size or interesting values
      delta = [-4, -1, 1, 4, 8, -8].sample(random: rng)
      value = rng.rand(3).zero? ? INTERESTING.sample(random: rng) : size + delta
      ["nsize#{index}@#{pos}=#{value}", put(bytes, pos + 4, value)]
    else # count / offset words in the body
      words = [(size - 8) / 4, FIELD_WORDS].min
      return ["noop#{index}", bytes] if words.zero?

      at = pos + 8 + (4 * rng.rand(words))
      old = bytes.byteslice(at, 4).unpack1("V")
      value = rng.rand(2).zero? ? INTERESTING.sample(random: rng) : old + [-1, 1, 4, 100, size].sample(random: rng)
      ["field#{index}@#{at}=#{value}", put(bytes, at, value)]
    end
  end

  def run(backend, library, bytes)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    observe_safely(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def observe_safely(bytes)
    JSON.parse(JSON.generate(MalformedParity.observe(bytes)))
  rescue StandardError, NoMemoryError, SystemStackError => e
    { "outcome" => "exception", "error" => { "class" => e.class.name, "message" => e.message[0, 200] } }
  end

  # :equal, :native_lenient (native parses, Ruby errors), :native_strict, :differ
  def direction(ruby, native)
    return :equal if ruby == native

    ruby_fail = %w[format_error exception].include?(ruby["outcome"])
    native_fail = %w[format_error exception].include?(native["outcome"])
    return :native_lenient if ruby_fail && !native_fail
    return :native_strict if native_fail && !ruby_fail
    return :native_lenient if ruby["outcome"] == "recovered" && native["outcome"] == "parsed"
    return :native_strict if ruby["outcome"] == "parsed" && native["outcome"] == "recovered"

    :differ
  end
end
