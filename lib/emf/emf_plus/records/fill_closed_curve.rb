# frozen_string_literal: true

require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillClosedCurve (2.3.4.15). S solid colour brush, C compressed, W winding fill, P relative points.
      class FillClosedCurve < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x4016

        class FillClosedCurveBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :brush_id
          float32_le :tension
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { flags.anybits?(ShapeFlags::RELATIVE_FLAG) },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = FillClosedCurveBody

        def flag_fields = super.merge(winding: 0x2000)

        def winding? = flags.anybits?(0x2000)
        def tension = body.tension
        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
