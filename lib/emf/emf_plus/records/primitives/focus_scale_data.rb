# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusFocusScaleData (2.2.2.18).
        class FocusScaleData < Body
          endian :little
          uint32 :focus_scale_count
          float32_le :focus_scale_x
          float32_le :focus_scale_y
        end
      end
    end
  end
end
