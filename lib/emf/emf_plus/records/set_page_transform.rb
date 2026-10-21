# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetPageTransform (2.3.9.5): page_unit is the low Flags byte (UnitType).
      class SetPageTransform < Base
        TYPE = 0x4030

        class SetPageTransformBody < Body
          endian :little
          float32_le :page_scale
        end
        BODY = SetPageTransformBody

        def flag_fields = { page_unit: 0x00FF }

        def page_unit = flags & 0x00FF
        def page_scale = body.page_scale
      end
    end
  end
end
