# frozen_string_literal: true

require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawClosedCurve (2.3.4.4). C compressed, P relative points; ObjectID is the pen.
      class DrawClosedCurve < Base
        include ShapeFlags

        TYPE = 0x4017

        class DrawClosedCurveBody < Body
          endian :little
          mandatory_parameter :flags
          float32_le :tension
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { flags.anybits?(ShapeFlags::RELATIVE_FLAG) },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawClosedCurveBody

        def pen_id = emf_object_id
        def tension = body.tension
        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
