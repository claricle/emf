# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # One EmfPlusInteger7 (2.2.2.21) or EmfPlusInteger15 (2.2.2.22). The
        # first byte decides: high bit clear is a 7-bit value, set is a 15-bit
        # value whose high byte comes first. The width is kept so it re-encodes.
        class RelativeCoordinate < Body
          endian :little
          uint8 :lead
          uint8 :low, onlyif: -> { lead.anybits?(0x80) }

          def wide? = lead.anybits?(0x80)

          def to_i
            wide? ? sign_extend(((lead & 0x7F) << 8) | low, 15) : sign_extend(lead, 7)
          end

          private

          def sign_extend(raw, bits)
            raw.anybits?(1 << (bits - 1)) ? raw - (1 << bits) : raw
          end
        end
      end
    end
  end
end
