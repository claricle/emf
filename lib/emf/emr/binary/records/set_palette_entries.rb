# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
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
            to_binary_s.byteslice(8..)
          end
        end
      end
    end
  end
end
