# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      module Records
        # Preserves unknown record bytes verbatim for round-trip safety.
        class Raw < BinData::Record
          endian :little
          uint32 :i_type
          uint32 :n_size
          rest :payload
        end
      end
    end
  end
end
