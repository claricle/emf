# frozen_string_literal: true

# Helpers for the forced-backend conformance parity spec: backend forcing, a
# first-difference locator and the synthetic Raw/recovery inputs.
module ConformanceParity
  NOW = Time.utc(2026, 1, 1)
  PROFILES = %i[strict tolerant].freeze
  KEYS = %w[EMF_BACKEND EMF_NATIVE_LIBRARY].freeze
  RAW_TYPE = 0x7F00

  module_function

  # Runs the block with the backend forced, restoring the prior environment.
  def with_backend(backend, library)
    previous = ENV.to_h.slice(*KEYS)
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library
    yield
  ensure
    KEYS.each { |key| ENV[key] = previous[key] }
  end

  # "path => expected vs actual" for the first difference, or nil when equal.
  def first_difference(left, right, path = "report")
    case [left, right]
    in [Hash, Hash] then hash_difference(left, right, path)
    in [Array, Array] then array_difference(left, right, path)
    else left == right ? nil : "#{path}: ruby=#{left.inspect} native=#{right.inspect}"
    end
  end

  def hash_difference(left, right, path)
    (left.keys | right.keys).each do |key|
      return "#{path}.#{key}: key present on one side only" unless left.key?(key) && right.key?(key)

      found = first_difference(left[key], right[key], "#{path}.#{key}")
      return found if found
    end
    nil
  end

  def array_difference(left, right, path)
    left.zip(right).each_with_index do |(a, b), index|
      return "#{path}[#{index}]: ruby=#{a.inspect} native=#{b.inspect}" if a.nil? || b.nil?

      found = first_difference(a, b, "#{path}[#{index}]")
      return found if found
    end
    left.size == right.size ? nil : "#{path}.size: ruby=#{left.size} native=#{right.size}"
  end

  # An unknown-type record (parsed as Raw) inserted before the closing EMR_EOF.
  def with_raw_record(bytes)
    eof = last_record_offset(bytes)
    raw = [RAW_TYPE, 16, 1, 2].pack("V4")
    out = bytes.byteslice(0, eof) + raw + bytes.byteslice(eof..)
    out.dup.tap { |copy| patch_header(copy, raw.bytesize) }
  end

  def last_record_offset(bytes)
    pos = bytes.byteslice(4, 4).unpack1("V")
    last = pos
    while pos + 8 <= bytes.bytesize
      size = bytes.byteslice(pos + 4, 4).unpack1("V")
      break if size < 8

      last = pos
      pos += size
    end
    last
  end

  def patch_header(bytes, added)
    bytes[48, 4] = [bytes.byteslice(48, 4).unpack1("V") + added].pack("V")
    bytes[52, 4] = [bytes.byteslice(52, 4).unpack1("V") + 1].pack("V")
  end
end
