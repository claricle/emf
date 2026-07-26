# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      # All EMR records share an 8-byte header: uint32 iType, uint32 nSize.
      # Subclasses add their own fields after this.
      class Record < BinData::Record
        endian :little
        uint32 :i_type
        uint32 :n_size
      end
    end
  end
end
