# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Exposes option-dependent text buffers without changing the wire layout.
        class PolyTextOutW < Emf::Emr::Binary::Record
          rest :body

          def c_strings
            checked_body(32).byteslice(28, 4).unpack1("V")
          end

          def bounds
            checked_body(16).byteslice(0, 16).b
          end

          def bounds=(value)
            replace_body_bytes(0, 16, value)
          end

          def text_bytes(index)
            read_span(text_span(index))
          end

          def set_text_bytes(index, value)
            replace_body_bytes(*text_span(index), value)
          end

          def dx_bytes(index)
            span = dx_span(index)
            read_span(span) if span
          end

          def set_dx_bytes(index, value)
            span = dx_span(index)
            raise ArgumentError, "text entry has no spacing buffer" unless span

            replace_body_bytes(*span, value)
          end

          def entry_bounds(index)
            span = entry_bounds_span(index)
            read_span(span) if span
          end

          def set_entry_bounds(index, value)
            span = entry_bounds_span(index)
            raise ArgumentError, "text entry has no bounds rectangle" unless span

            replace_body_bytes(*span, value)
          end

          private

          def checked_body(required)
            bytes = body.to_s
            raise ArgumentError, "truncated poly text output body" if bytes.bytesize < required

            bytes
          end

          def entry_location(index)
            bytes = checked_body(32)
            count = bytes.byteslice(28, 4).unpack1("V")
            raise ArgumentError, "invalid text entry index" unless index.is_a?(Integer) && index >= 0 && index < count
            raise ArgumentError, "truncated text entry table" if count > (bytes.bytesize - 32) / 24

            offset = 32
            selected = nil
            count.times do |position|
              raise ArgumentError, "truncated text entry table" if bytes.bytesize - offset < 24

              options = bytes.byteslice(offset + 16, 4).unpack1("V")
              length = options.nobits?(0x100) ? 40 : 24
              raise ArgumentError, "truncated text entry table" if bytes.bytesize - offset < length

              selected = offset if position == index
              offset += length
            end
            [bytes, selected, offset]
          end

          def text_span(index)
            bytes, offset, table_end = entry_location(index)
            count, pointer = bytes.byteslice(offset + 8, 8).unpack("V2")
            buffer_span(bytes, pointer, count * 2, table_end, 2)
          end

          def dx_span(index)
            bytes, offset, table_end = entry_location(index)
            count = bytes.byteslice(offset + 8, 4).unpack1("V")
            options = bytes.byteslice(offset + 16, 4).unpack1("V")
            pointer_at = options.nobits?(0x100) ? 36 : 20
            pointer = bytes.byteslice(offset + pointer_at, 4).unpack1("V")
            return nil if pointer.zero?

            width = options.nobits?(0x2000) ? 4 : 8
            buffer_span(bytes, pointer, count * width, table_end, 4)
          end

          def entry_bounds_span(index)
            bytes, offset, = entry_location(index)
            options = bytes.byteslice(offset + 16, 4).unpack1("V")
            [offset + 20, 16] if options.nobits?(0x100)
          end

          def buffer_span(bytes, pointer, length, table_end, alignment)
            return [0, 0] if length.zero?

            raise ArgumentError, "misaligned text entry buffer" unless (pointer % alignment).zero?

            offset = pointer - 8
            if offset < table_end || offset > bytes.bytesize || length > bytes.bytesize - offset
              raise ArgumentError, "invalid text entry buffer span"
            end

            [offset, length]
          end

          def read_span(span)
            offset, length = span
            body.to_s.byteslice(offset, length).b
          end

          def replace_body_bytes(offset, length, value)
            bytes = checked_body(offset + length)
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "poly text output value must be a String of #{length} bytes"
            end

            replacement = bytes.b
            replacement[offset, length] = value.b
            self.body = replacement
          end
        end
      end
    end
  end
end
