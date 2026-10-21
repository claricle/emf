# frozen_string_literal: true

require "pathname"

# Deterministic WMF mutation corpus plus a backend-neutral observation of one parse.
module WmfMutation
  ROOT = Pathname(__dir__).join("../..").expand_path
  SEED_GLOBS = %w[emf-rs/fuzz/seeds/wmf-resilience/*.wmf spec/fixtures/wmf/*.wmf].freeze
  REPLACEMENTS = [0x00, 0xFF, 0x80, 0x01, 0x7F].freeze
  RANDOM_PER_SEED = 90
  RANDOM_SEED = 20_261_021

  module_function

  def seeds
    SEED_GLOBS.flat_map { |glob| Dir[ROOT.join(glob)].sort }.to_h { |path| [File.basename(path, ".wmf"), File.binread(path)] }
  end

  # Returns [label, bytes] pairs; labels name the seed and the mutation so a failure is reproducible.
  def corpus(seeds = self.seeds)
    random = Random.new(RANDOM_SEED)
    seeds.flat_map do |name, bytes|
      truncations(name, bytes) + substitutions(name, bytes) + appended(name, bytes) + scattered(name, bytes, random)
    end
  end

  def truncations(name, bytes)
    (0...bytes.bytesize).map { |length| ["#{name} truncate #{length}", bytes.byteslice(0, length)] }
  end

  def substitutions(name, bytes)
    bytes.bytesize.times.flat_map do |offset|
      (REPLACEMENTS + [bytes.getbyte(offset) ^ 0x02]).uniq.reject { |value| value == bytes.getbyte(offset) }.map do |value|
        mutated = bytes.dup
        mutated.setbyte(offset, value)
        ["#{name} set #{offset}=#{value}", mutated]
      end
    end
  end

  def appended(name, bytes)
    [["#{name} append 1", bytes + "\x00".b], ["#{name} append 5", bytes + "\xA5\x5A\x01\x02\x03".b],
     ["#{name} append eof", bytes + [3, 0].pack("Vv")]]
  end

  def scattered(name, bytes, random)
    Array.new(RANDOM_PER_SEED) do |index|
      mutated = bytes.dup
      flips = random.rand(1..4)
      flips.times { mutated.setbyte(random.rand(mutated.bytesize), random.rand(256)) }
      ["#{name} random #{index}", mutated]
    end
  end

  def observe(bytes, backend, library)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library if backend == "native"
    observe_current(bytes)
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| previous[key] ? ENV[key] = previous[key] : ENV.delete(key) }
  end

  def observe_current(bytes)
    metafile = Emf.parse(bytes)
    return [:nil_result] unless metafile

    [:parsed, metafile.format, dump(metafile.header), metafile.records.map { |record| dump(record) }, metafile.trailing,
     serialized(metafile)]
  rescue Emf::ParseError => e
    [:parse_error, e.class.name, e.offset, e.record_code, e.message]
  rescue Emf::Error => e
    [:error, e.class.name, e.message]
  end

  def serialized(metafile)
    Emf.serialize(metafile)
  rescue Emf::Error => e
    [:serialize_error, e.class.name, e.message]
  end

  def dump(value)
    case value
    when Array then value.map { |item| dump(item) }
    when String, Integer, Symbol, nil, true, false, Float then value
    else [value.class.name, value.instance_variables.sort.map { |name| [name, dump(value.instance_variable_get(name))] }]
    end
  end
end
