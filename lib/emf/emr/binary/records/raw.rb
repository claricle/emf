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

          # Not a Record, so it has no built fast path: just its bytes.
          def append_built_to?(_out) = false
        end
      end
    end
  end
end
