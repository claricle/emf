# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Reads the EMRTEXT string and Dx array of EMR_EXTTEXTOUTA/W from the
      # record bytes. Offsets are from record start; a missing or out-of-range
      # part is nil, never an error.
      module ExtTextOutFields
        ETO_NO_RECT = 0x100
        ETO_PDY = 0x2000

        # Raw string bytes (nChars * #char_size at offString), or nil.
        def string_bytes
          slice_of_record(off_string, n_chars * char_size)
        end

        # The string as UTF-8, or nil. See the A/W classes for the decoding.
        def text
          bytes = string_bytes
          bytes && decode_text(bytes)
        end

        # Dx array: unsigned 32-bit values at offDx, nChars of them (2 * nChars
        # with ETO_PDY), or nil when offDx is 0 or the range leaves the record.
        def dx
          count = n_chars * (f_options.anybits?(ETO_PDY) ? 2 : 1)
          bytes = slice_of_record(off_dx, count * 4)
          bytes&.unpack("V*")
        end

        private

        def slice_of_record(offset, length)
          return unless offset.positive? && length.positive?

          bytes = to_binary_s
          bytes.byteslice(offset, length) if offset + length <= bytes.bytesize
        end
      end
    end
  end
end
