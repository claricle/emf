# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillRegion (2.3.4.21). S solid colour brush; ObjectID is the region.
      class FillRegion < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x4013

        class FillRegionBody < Body
          endian :little
          uint32 :brush_id
        end
        BODY = FillRegionBody

        def region_id = emf_object_id
      end
    end
  end
end
