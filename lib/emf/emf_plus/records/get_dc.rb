# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusGetDC (2.3.3.2): no body. Following EMF records are drawable
      # until the next EMF+ record, so its position in the stream matters.
      class GetDC < Base
        TYPE = 0x4004

        class GetDCBody < BinData::Record
          endian :little
        end
        BODY = GetDCBody
      end
    end
  end
end
