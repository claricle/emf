# frozen_string_literal: true

require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillPolygon (2.3.4.19). S solid colour brush, C compressed, P relative points.
      class FillPolygon < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x400C

        class FillPolygonBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :brush_id
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { flags.anybits?(ShapeFlags::RELATIVE_FLAG) },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = FillPolygonBody

        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
