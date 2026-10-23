# frozen_string_literal: true

module Emf
  class ResourceBudget
    module PolyText
      module_function

      def decode(kind, payload, budget) # rubocop:disable Naming/PredicateMethod
        return false if payload.length < 32

        count = payload.u32(28)
        return false if count > (payload.length - 32) / 24

        budget.charge_work(count)
        fixed = table_end(payload, count)
        return false unless fixed

        width = kind == 96 ? 1 : 2
        budget.vector(count, budget.layout(width == 1 ? :poly_text_entry_a : :poly_text_entry_w))
        budget.vector(count * 2, budget.layout(:poly_text_span))
        spans = []
        cursor = 32
        count.times do |index|
          entry = entry_spans(payload, budget, cursor, fixed, width, index)
          return false unless entry

          cursor, ranges = entry
          spans.concat(ranges)
        end
        budget.charge_work(spans.length * spans.length.bit_length)
        cursor = fixed
        spans.sort!.each do |start, stop, _index, _is_dx|
          return false if start < cursor

          unused = start - cursor
          budget.charge_work((unused + 15) / 16)
          budget.vector(unused, 1)
          cursor = stop
        end
        true
      end

      def entry_spans(payload, budget, cursor, fixed, width, index)
        chars = payload.u32(cursor + 8)
        string = payload.u32(cursor + 12)
        options = payload.u32(cursor + 16)
        descriptor_size = options.anybits?(0x100) ? 24 : 40
        dx = payload.u32(cursor + descriptor_size - 4)
        dx_count = chars * (options.anybits?(0x2000) ? 2 : 1)
        spans = []
        unless string.zero? && chars.zero?
          range = budget.span(payload.length, string, chars * width, width, fixed)
          return unless range

          spans << [*range, index, 0]
        end
        unless dx.zero?
          range = budget.span(payload.length, dx, dx_count * 4, 4, fixed)
          return unless range

          spans << [*range, index, 1]
        end
        budget.charge_work(chars)
        budget.vector(chars, width)
        unless dx.zero?
          budget.charge_work(dx_count)
          budget.vector(dx_count, 4)
        end
        [cursor + descriptor_size, spans]
      end

      def table_end(payload, count)
        cursor = 32
        count.times do
          return if payload.length - cursor < 24

          options = payload.u32(cursor + 16)
          cursor += options.anybits?(0x100) ? 24 : 40
          return if cursor > payload.length
        end
        cursor
      end
    end
  end
end
