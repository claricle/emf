# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusFocusScaleData (2.2.2.18).
        class FocusScaleData < Body
          endian :little
          uint32 :focus_scale_count
          float :focus_scale_x
          float :focus_scale_y
        end
      end
    end
  end
end
