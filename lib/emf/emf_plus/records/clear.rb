# frozen_string_literal: true

require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      # EmfPlusClear (2.3.4.1). Flags are unused.
      class Clear < Base
        TYPE = 0x4009

        class ClearBody < BinData::Record
          endian :little
          argb :color
        end
        BODY = ClearBody

        def color = body.color
      end
    end
  end
end
