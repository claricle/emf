# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_COMMENT: iType, nSize, cbData, then Data[cbData].
        # The Data may carry an EMF+ stream (identifier 0x2B464D45),
        # a public comment, a spool comment, or arbitrary private data.
        class Comment < Emf::Emr::Binary::Record
          uint32 :cb_data
          rest :data
        end
      end
    end
  end
end
