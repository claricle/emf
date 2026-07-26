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
        end
      end
    end
  end
end
