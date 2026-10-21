# frozen_string_literal: true

require "emf"
require_relative "backend_parity"
require_relative "native_corpus_parity"

# Synthetic per-record variant acceptance. Each variant is built byte-by-byte
# from the MS-EMF layout (not from the Ruby wire classes), parsed by both the
# Ruby and native backends, and compared on canonical fields, diagnostics and
# exact serialization. A field tuple carries its own expectation, so the bytes
# and the typed-field assertion share one source.
module RecordVariants
  Field = Struct.new(:path, :pack, :value)
  Variant = Struct.new(:record, :name, :type, :fields, :size, :kind, :pending, :raw_class)

  UINT_MAX = 0xFFFF_FFFF
  INT_MIN = -2**31
  INT_MAX = (2**31) - 1

  REGISTRY = {} # rubocop:disable Style/MutableConstant
  EOF_RECORD = [14, 20, 0, 0, 20].pack("V5")
  HEADER_BYTES = lambda do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end

  # Field builders shared by every catalog.
  module Fields
    module_function

    def u32(path, value) = [Field.new(path, "V", value)]
    def i32(path, value) = [Field.new(path, "l<", value)]
    def u16(path, value) = [Field.new(path, "v", value)]
    def i16(path, value) = [Field.new(path, "s<", value)]
    def u8(path, value) = [Field.new(path, "C", value)]
    def f32(path, value) = [Field.new(path, "e", value)]
    def raw(path, bytes) = [Field.new(path, "a*", bytes.b)]

    def rectl(path, left, top, right, bottom)
      i32("#{path}.left", left) + i32("#{path}.top", top) + i32("#{path}.right", right) + i32("#{path}.bottom", bottom)
    end

    def pointl(path, x, y) = i32("#{path}.x", x) + i32("#{path}.y", y)
    def sizel(path, cx, cy) = i32("#{path}.cx", cx) + i32("#{path}.cy", cy)

    def colorref(path, red, green, blue, reserved = 0)
      u8("#{path}.red", red) + u8("#{path}.green", green) + u8("#{path}.blue", blue) + u8("#{path}.reserved", reserved)
    end

    def xform(path, *values)
      %w[m11 m12 m21 m22 dx dy].zip(values).flat_map { |name, value| f32("#{path}.#{name}", value) }
    end

    def points_l(path, points)
      points.each_with_index.flat_map { |(x, y), i| pointl("#{path}[#{i}]", x, y) }
    end

    def points_s(path, points)
      points.each_with_index.flat_map { |(x, y), i| i16("#{path}[#{i}].x", x) + i16("#{path}[#{i}].y", y) }
    end

    def u32_list(path, values)
      values.each_with_index.flat_map { |value, i| u32("#{path}[#{i}]", value) }
    end

    def bytes_list(path, values)
      values.each_with_index.flat_map { |value, i| u8("#{path}[#{i}]", value) }
    end

    # Expectation without wire bytes: a derived accessor such as text_bytes(0).
    def check(path, value) = [Field.new(path, nil, value)]

    # Unchecked bytes: padding or a region whose accessors are covered elsewhere.
    def pad(bytes) = [Field.new(nil, "a*", bytes.b)]
  end

  # Declares the variants of one registry class.
  class Entry
    include Fields

    attr_reader :name, :type, :variants, :derived_pending

    def initialize(name, type)
      @name = name
      @type = type
      @variants = []
      @derived_pending = {}
    end

    # Marks one derived control (:truncated, :padded, :size_beyond_input) pending.
    def pending_derived(label, reason)
      @derived_pending[label] = reason
    end

    def valid(label, *fields, pending: nil)
      add(label, fields.flatten, :valid, nil, pending)
    end

    # Well-formed framing whose body the parsers must treat identically but
    # whose fields are not asserted (bounds-check and recovery controls).
    def malformed(label, *fields, size: nil, pending: nil, raw: false)
      add(label, fields.flatten, :malformed, size, pending, raw)
    end

    private

    def add(label, fields, kind, size, pending, raw = false)
      @variants << Variant.new(name, label, type, fields, size, kind, pending, raw)
    end
  end

  module_function

  def define(name, type, &)
    entry = Entry.new(name, type)
    entry.instance_eval(&)
    REGISTRY[name] = entry
  end

  def record_bytes(variant)
    body = variant.fields.filter_map { |field| [field.value].pack(field.pack) if field.pack }.join.b
    size = variant.size || (8 + body.bytesize)
    [variant.type, size].pack("V2") + body
  end

  def source(variant)
    "#{HEADER_BYTES.call}#{record_bytes(variant)}#{EOF_RECORD}".b
  end

  def derived(entry)
    base = entry.variants.reverse.find { |variant| variant.kind == :valid }
    return [] unless base

    bytes = record_bytes(base)
    [[:truncated, bytes.byteslice(0, bytes.bytesize - 4), bytes.bytesize - 4],
     [:padded, bytes + ([0xA5] * 4).pack("C*"), bytes.bytesize + 4],
     [:size_beyond_input, bytes, bytes.bytesize + 16]].map do |label, data, size|
      data = data.dup
      data[4, 4] = [size].pack("V")
      [label, data]
    end
  end
end
