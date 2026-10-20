# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/palette_body"
require "emf/emr/binary/palette_entry"

module Emf
  module Emr
    module Binary
      module Records
        class SetPaletteEntries < Emf::Emr::Binary::Record
          uint32 :ih_pal
          uint32 :start
          uint32 :entry_count
          array :palette_entries, type: :emr_palette_entry, initial_length: :entry_count
          rest :trailing

          def body
            PaletteBody.new(self, to_binary_s.byteslice(8..))
          end

          def body=(value)
            bytes = value.to_s
            count = bytes.byteslice(8, 4)&.unpack1("V")
            raise ArgumentError, "invalid palette body entry count" unless count && bytes.bytesize >= 12 + (count * 4)

            replacement = self.class.read(to_binary_s.byteslice(0, 8) + bytes)
            assign(replacement.snapshot)
          end
        end
      end
    end
  end
end
