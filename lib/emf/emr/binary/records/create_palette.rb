# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/palette_entry"

module Emf
  module Emr
    module Binary
      module Records
        class CreatePalette < Emf::Emr::Binary::Record
          uint32 :ih_pal
          uint16 :version
          uint16 :entry_count
          array :palette_entries, type: :emr_palette_entry, initial_length: :entry_count
          rest :trailing

          def body
            to_binary_s.byteslice(12..)
          end
        end
      end
    end
  end
end
