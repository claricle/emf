# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetPageTransform (2.3.9.5): page_unit is the low Flags byte (UnitType).
      class SetPageTransform < Base
        TYPE = 0x4030

        class SetPageTransformBody < BinData::Record
          endian :little
          float :page_scale
        end
        BODY = SetPageTransformBody

        def flag_fields = { page_unit: 0x00FF }

        def page_unit = flags & 0x00FF
        def page_scale = body.page_scale
      end
    end
  end
end
