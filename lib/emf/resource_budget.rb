# frozen_string_literal: true

module Emf
  # Replays the native parser's admission charges without materializing decoded
  # records. Malformed fatal headers return control to the existing parser.
  class ResourceBudget # rubocop:disable Metrics/ClassLength
    DEFAULT_LIMITS = {
      input_bytes: 200 * 1024 * 1024,
      record_bytes: 128 * 1024 * 1024,
      record_count: 4 * 1024 * 1024,
      allocated_bytes: 640 * 1024 * 1024,
      work_units: 64 * 1024 * 1024
    }.freeze

    # Rust layouts observed in the existing arm64-darwin25 emf-core artifact by
    # lowered allocation ceilings. Other target layouts are not yet verified.
    LAYOUT = {
      record_span: 336, diagnostic: 32, font_record: 392,
      poly_text_entry_a: 136, poly_text_entry_w: 136,
      poly_text_span: 32, tri_vertex: 16
    }.freeze
    RECORD_SPAN_BYTES = LAYOUT.fetch(:record_span)
    DIAGNOSTIC_BYTES = LAYOUT.fetch(:diagnostic)
    FONT_RECORD_BYTES = LAYOUT.fetch(:font_record)

    FIXED_PAYLOADS = {
      9 => 8, 10 => 8, 11 => 8, 12 => 8, 13 => 8, 14 => 12, 15 => 12,
      16 => 4, 17 => 4, 18 => 4, 19 => 4, 20 => 4, 21 => 4, 22 => 4,
      24 => 4, 25 => 4, 26 => 8, 27 => 8, 28 => 0, 29 => 16, 30 => 16,
      31 => 16, 32 => 16, 33 => 0, 34 => 4, 35 => 24, 36 => 28, 37 => 4,
      38 => 20, 39 => 16, 40 => 4, 41 => 20, 42 => 16, 43 => 16, 44 => 24,
      45 => 32, 46 => 32, 47 => 32, 48 => 4, 51 => 8, 52 => 0, 53 => 16, 54 => 8,
      55 => 32, 57 => 4, 58 => 4, 59 => 0, 60 => 0, 61 => 0, 62 => 16,
      63 => 16, 64 => 16, 65 => 0, 66 => 0, 67 => 4, 68 => 0, 98 => 4,
      115 => 4, 120 => 8
    }.freeze

    # A borrowed payload; reading fields must not copy a potentially large body.
    class Payload
      attr_reader :length
      alias bytesize length

      def initialize(bytes, base, length)
        @bytes = bytes
        @base = base
        @length = length
      end

      def u32(offset)
        @bytes.unpack1("V", offset: @base + offset)
      end

      def u16(offset)
        @bytes.unpack1("v", offset: @base + offset)
      end

      def slice(offset, length)
        self.class.new(@bytes, @base + offset, length)
      end
    end

    def self.check!(bytes, limits: {}, &admission)
      new(limits).replay!(bytes, &admission)
    end

    def initialize(limits = {})
      @limits = DEFAULT_LIMITS.merge(limits)
      @totals = { record_count: 0, allocated_bytes: 0, work_units: 0 }
      @vectors = {}
    end

    def charge_alloc(bytes)
      charge(:allocated_bytes, bytes)
    end

    def charge_work(units)
      charge(:work_units, units)
    end

    def layout(name)
      LAYOUT.fetch(name)
    end

    def vector(count, width)
      charge_alloc(count * width)
    end

    def span(payload_length, offset, length, alignment, fixed, empty_boundary: false)
      return if offset < 8 || offset % alignment != 0

      start = offset - 8
      start = [start, fixed].max if empty_boundary && length.zero?
      finish = start + length
      [start, finish] if start >= fixed && finish <= payload_length
    end

    def replay!(bytes, &) # rubocop:disable Naming/PredicateMethod
      check(:input_bytes, bytes.bytesize)
      return true unless Detector.call(bytes) == :emf

      input = Payload.new(bytes, 0, bytes.bytesize)
      header_size = input.u32(4)
      minimum = if header_size > 100 then 108
                elsif header_size > 88 then 100
                else 88
                end
      return true if header_size < minimum

      check(:record_bytes, header_size)
      charge_record(header_size)
      return true if header_size > input.length

      charge_work(ceil16(input.length))
      charge_alloc(input.length)
      replay_records(input, header_size, &)
      true
    end

    private

    def check(resource, actual)
      limit = @limits.fetch(resource)
      return if actual <= limit

      raise ResourceLimitError.new(resource: resource, limit: limit, actual: actual)
    end

    def charge(resource, amount)
      total = @totals.fetch(resource) + amount
      check(resource, total)
      @totals[resource] = total
    end

    def ceil16(bytes)
      (bytes + 15) / 16
    end

    def charge_record(size)
      charge(:record_count, 1)
      charge_work(1 + ceil16(size))
    end

    def reserve(name, width)
      length, capacity = @vectors.fetch(name, [0, 0])
      if length == capacity
        capacity = [capacity * 2, 1].max
        charge_alloc(capacity * width)
      end
      @vectors[name] = [length + 1, capacity]
    end

    def diagnostic
      reserve(:diagnostics, DIAGNOSTIC_BYTES)
    end

    def replay_records(input, offset)
      while offset < input.length
        remaining = input.length - offset
        if remaining < 8 || (size = input.u32(offset + 4)) < 8 || size > remaining
          diagnostic
          break
        end
        kind = input.u32(offset)
        check(:record_bytes, size)
        charge_record(size)
        reserve(:records, RECORD_SPAN_BYTES)
        payload = input.slice(offset + 8, size - 8)
        typed = decode(kind, payload)
        diagnostic if !typed && invalid_when_raw?(kind, payload.length)
        yield kind, size, offset if block_given?
        offset += size
        break if kind == 14 && typed
      end
    end

    def invalid_when_raw?(kind, length)
      prefix = if kind == 118 then 28
               elsif Bitmap::SHAPES.key?(kind) then Bitmap::SHAPES.fetch(kind).first - 8
               end
      return length < prefix if prefix
      return false if [23, 96, 97].include?(kind)
      return length < 28 if kind == 108

      (2..68).cover?(kind) || (70..98).cover?(kind) || (114..116).cover?(kind) || kind == 120
    end

    def decode_delegated(kind, payload)
      case kind
      when 96, 97 then PolyText.decode(kind, payload, self)
      when 118 then Gradient.decode(kind, payload, self)
      else Bitmap.decode(kind, payload, self)
      end
    end

    # Keep native match-arm order visible for charge and recovery parity.
    def decode(kind, payload) # rubocop:disable Metrics/CyclomaticComplexity
      case kind
      when 2..6, 85..89 then decode_poly?(payload, kind < 85 ? 8 : 4)
      when 7, 8, 90, 91 then decode_multi_poly?(payload, kind < 90 ? 8 : 4)
      when 56, 92 then decode_poly?(payload, (kind == 56 ? 8 : 4) + 1, 2)
      when 49, 50 then decode_palette?(kind, payload)
      when 70 then decode_comment?(payload)
      when 71..75 then decode_region?(kind, payload)
      when 82 then decode_font?(payload)
      when 83, 84 then decode_text?(payload, kind == 83 ? 1 : 2)
      when 95 then decode_pen?(payload)
      when 23 then true
      when 76..81, 93, 94, 96, 97, 114, 116, 118 then decode_delegated(kind, payload)
      else
        fixed = FIXED_PAYLOADS[kind]
        fixed && payload.length >= fixed
      end
    end

    def decode_poly?(payload, width, work_multiplier = 1)
      return false if payload.length < 20

      count = payload.u32(16)
      bytes = count * width
      return false if bytes > payload.length - 20

      charge_alloc(bytes)
      charge_work(count * work_multiplier)
      true
    end

    def decode_multi_poly?(payload, width)
      return false if payload.length < 24

      polygons = payload.u32(16)
      points = payload.u32(20)
      bytes = (polygons * 4) + (points * width)
      return false if bytes > payload.length - 24

      charge_alloc(bytes)
      charge_work(polygons + points)
      true
    end

    def decode_palette?(kind, payload)
      fixed = kind == 49 ? 8 : 12
      return false if payload.length < fixed

      count = kind == 49 ? payload.u16(6) : payload.u32(8)
      return false if count * 4 > payload.length - fixed

      charge_alloc(count * 4)
      charge_work(count)
      true
    end

    def decode_comment?(payload)
      return false if payload.length < 4

      count = payload.u32(0)
      return false if count > payload.length - 4

      charge_alloc(count)
      charge_work(ceil16(count))
      true
    end

    def decode_region?(kind, payload)
      fixed = { 71 => 24, 72 => 32, 73 => 20, 74 => 20, 75 => 8 }.fetch(kind)
      return false if payload.length < fixed

      count = payload.u32(kind == 75 ? 0 : 16)
      return false if count > payload.length - fixed
      return true if count.zero? && kind == 75
      return false if count < 32

      region = payload.slice(fixed, count)
      rectangles = region.u32(8)
      bytes = rectangles * 16
      return false unless region.u32(0) == 32 && region.u32(12) == bytes && bytes <= count - 32

      extra = count - 32 - bytes
      charge_alloc(bytes)
      charge_alloc(extra)
      charge_work(rectangles)
      charge_work(ceil16(extra))
      true
    end

    def decode_font?(payload)
      return false if payload.length < 96

      size = payload.length - 4
      if size > 320
        return false if size < 356

        count = payload.u32(356)
        return false unless payload.u32(352) == 0x08007664 && count <= 16 && count * 4 <= payload.length - 360

        charge_alloc(count * 4)
        charge_work(count)
      end
      charge_alloc(FONT_RECORD_BYTES)
      true
    end

    # Span validation and charging follow native decode_text in order.
    def decode_text?(payload, width) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return false if payload.length < 52

      count = payload.u32(36)
      options = payload.u32(44)
      fixed = options.nobits?(0x100) ? 68 : 52
      return false if payload.length < fixed

      string_len = count * width
      dx_count = count * (options.nobits?(0x2000) ? 1 : 2)
      string_offset = payload.u32(40)
      dx_offset = payload.u32(fixed - 4)
      string = span(payload.length, string_offset, string_len, width, fixed) unless string_offset.zero? && count.zero?
      dx = span(payload.length, dx_offset, dx_count * 4, 4, fixed) unless dx_offset.zero?
      return false if (!string_offset.zero? || !count.zero?) && !string
      return false if !dx_offset.zero? && !dx
      return false if string && dx && string[0] < dx[1] && dx[0] < string[1]

      ranges = [string, dx].compact.sort_by(&:first)
      cursor = fixed
      ranges.each do |start, finish|
        return false if start < cursor

        charge_work(ceil16(start - cursor))
        charge_alloc(start - cursor)
        cursor = finish
      end
      charge_work(count)
      charge_alloc(string_len)
      if dx
        charge_work(dx_count)
        charge_alloc(dx_count * 4)
      end
      true
    end

    # Validate all spans before the first native pen allocation charge.
    def decode_pen?(payload) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return false if payload.length < 44

      count = payload.u32(40)
      fixed = 44 + (count * 4)
      return false if fixed > payload.length

      ranges = [[payload.u32(4), payload.u32(8)], [payload.u32(12), payload.u32(16)]].map do |offset, length|
        next if offset.zero? && length.zero?

        range = span(payload.length, offset, length, 4, fixed, empty_boundary: true)
        return false unless range

        range
      end
      info, bits = ranges
      bits_first = bits && (!info || bits[0] < info[0] || (bits[0] == info[0] && bits[0] == bits[1]))
      ranges = (bits_first ? [bits, info] : [info, bits]).compact
      cursor = fixed
      ranges.each do |start, finish|
        return false if start < cursor

        cursor = finish
      end
      charge_alloc(count * 4)
      charge_work(count)
      cursor = fixed
      ranges.each do |start, finish|
        [start - cursor, finish - start].each do |length|
          charge_alloc(length)
          charge_work(ceil16(length))
        end
        cursor = finish
      end
      true
    end
  end
end

require_relative "resource_budget/bitmap"
require_relative "resource_budget/poly_text"
require_relative "resource_budget/gradient"
