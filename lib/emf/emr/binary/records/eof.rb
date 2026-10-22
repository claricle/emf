# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EOF: iType, nSize, nPalEntries, offPalEntries, nSizeLast,
        # then optional palette data and description (per MS-EMF 2.3.3).
        class Eof < Emf::Emr::Binary::Record
          uint32 :n_pal_entries
          uint32 :off_pal_entries
          uint32 :n_size_last
          rest :body

          # Raw palette bytes (nPalEntries * 4 at offPalEntries from record start),
          # or nil when there are no entries or the range leaves the record.
          def palette_bytes
            return unless n_pal_entries.positive? && off_pal_entries.positive?

            bytes = to_binary_s
            bytes.byteslice(off_pal_entries, n_pal_entries * 4) if off_pal_entries + (n_pal_entries * 4) <= bytes.bytesize
          end
        end
      end
    end
  end
end
