# frozen_string_literal: true

module Emf
  class ResourceBudget
    # Mirror bitmap.rs range validation before charging each copied buffer.
    module Bitmap
      SHAPES = {
        76 => [100, 84, nil], 77 => [108, 84, nil],
        78 => [128, 84, 112], 79 => [140, 96, 124],
        80 => [76, 48, nil], 81 => [80, 48, nil],
        93 => [32, 16, nil], 94 => [32, 16, nil],
        114 => [108, 84, nil], 116 => [108, 84, nil]
      }.freeze
      KINDS = SHAPES.keys.freeze

      module_function

      def fixed_payload_len(kind)
        SHAPES.fetch(kind).first - 8
      end

      def decode(kind, payload, budget) # rubocop:disable Naming/PredicateMethod
        fixed, source, mask = SHAPES.fetch(kind)
        fixed -= 8
        return false if payload.length < fixed

        spans = buffer_spans(payload, fixed, source, mask)
        return false unless spans

        cursor = fixed
        spans.each do |start, stop|
          return false if start < cursor

          cursor = stop
        end
        cursor = fixed
        spans.each do |start, stop|
          [start - cursor, stop - start].each do |length|
            budget.charge_alloc(length)
            budget.charge_work((length + 15) / 16)
          end
          cursor = stop
        end
        true
      end

      def buffer_spans(payload, fixed, source, mask)
        mask_bits = mask + 8 if mask
        spans = [source, source + 8, mask, mask_bits].filter_map do |at|
          next unless at

          offset = payload.u32(at - 8)
          length = payload.u32(at - 4)
          next if offset.zero? && length.zero?

          start = offset - 8
          stop = start + length
          return nil if start < fixed || stop > payload.length

          [start, stop]
        end
        spans.sort_by! { |start, stop| [start, stop - start] }
      end
    end
  end
end
