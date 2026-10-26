# frozen_string_literal: true

module Emf
  module ResourceLimits
    # Admission follows the native framing rules without decoding a Ruby model.
    # Corrupt spans are left to the selected parser's existing recovery path.
    module EmfRecords
      MAX_RECORD_BYTES = 128 * 1024 * 1024
      MAX_RECORDS = 4 * 1024 * 1024
      POINT_WIDTHS = { 2 => 8, 3 => 8, 4 => 8, 5 => 8, 6 => 8,
                       85 => 4, 86 => 4, 87 => 4, 88 => 4, 89 => 4,
                       56 => 9, 92 => 5 }.freeze
      MULTI_WIDTHS = { 7 => 8, 8 => 8, 90 => 4, 91 => 4 }.freeze
      REGION_OFFSETS = { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 }.freeze

      module_function

      def check(bytes)
        count = 0
        each(bytes) do |type, size, base|
          ResourceLimits.check!(:record_bytes, MAX_RECORD_BYTES, size)
          count += 1
          ResourceLimits.check!(:record_count, MAX_RECORDS, count)
          check_arrays(bytes, type, size, base) if base.positive?
        end
      end

      def each(bytes)
        return if bytes.bytesize < 8

        size = bytes.unpack1("V", offset: 4)
        minimum = if size > 100
                    108
                  else
                    size > 88 ? 100 : 88
                  end
        return if size < minimum

        # The native header checks its claimed size before reading its body.
        yield 1, size, 0
        base = size
        while bytes.bytesize - base >= 8
          type = bytes.unpack1("V", offset: base)
          size = bytes.unpack1("V", offset: base + 4)
          return if size < 8 || size > bytes.bytesize - base

          yield type, size, base
          return if type == 14 && size >= 20

          base += size
        end
      end

      def check_arrays(bytes, type, size, base)
        if (width = POINT_WIDTHS[type])
          check_single(bytes, size, base, 24, 28, width)
        elsif (width = MULTI_WIDTHS[type])
          check_multi(bytes, size, base, width)
        elsif type == 50
          check_single(bytes, size, base, 16, 20, 4)
        elsif type == 95
          check_pen(bytes, size, base)
        elsif REGION_OFFSETS.key?(type)
          check_region(bytes, type, size, base)
        end
      end

      def check_single(bytes, size, base, count_at, fixed, width)
        return if size < fixed

        count = bytes.unpack1("V", offset: base + count_at)
        check_count(count) if fixed + (count * width) <= size
      end

      def check_multi(bytes, size, base, width)
        return if size < 32

        polys, points = bytes.unpack("V2", offset: base + 24)
        return if 32 + (polys * 4) + (points * width) > size

        check_count(polys)
        check_count(points)
      end

      def check_pen(bytes, size, base)
        return if size < 52

        count = bytes.unpack1("V", offset: base + 48)
        fixed = 52 + (count * 4)
        return if fixed > size

        info, info_length, bits, bits_length = bytes.unpack("V4", offset: base + 12)
        spans = [[info, info_length], [bits, bits_length]].map { |offset, length| pen_span(offset, length, fixed, size) }
        return if spans.any?(&:nil?)

        spans.sort_by! { |start, length| [start, length.zero? ? 0 : 1] }
        return if spans.size == 2 && spans[0].sum > spans[1][0]

        check_count(count)
      end

      def pen_span(offset, length, fixed, size)
        return [fixed, 0] if offset.zero? && length.zero?

        start = length.zero? ? [offset, fixed].max : offset
        return unless offset >= 8 && (offset % 4).zero? && start >= fixed && start + length <= size

        [start, length]
      end

      def check_region(bytes, type, size, base)
        fixed = REGION_OFFSETS.fetch(type)
        return if size < fixed

        length = bytes.unpack1("V", offset: base + (type == 75 ? 8 : 24))
        return if length < 32 || fixed + length > size

        header, _kind, count, rectangle_bytes = bytes.unpack("V4", offset: base + fixed)
        return unless header == 32 && count * 16 == rectangle_bytes && 32 + rectangle_bytes <= length

        check_count(count)
      end

      def check_count(count, record_bytes: 0)
        ResourceLimits.check!(:array_elements, Emr::Parser::MAX_SANE_ARRAY_LENGTH, count)
        ResourceLimits.check!(:record_bytes, 0xFFFFFFFF, record_bytes)
      end
    end
  end
end
