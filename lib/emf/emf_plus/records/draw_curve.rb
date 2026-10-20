# frozen_string_literal: true

require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawCurve (2.3.4.5). C selects Point over PointF; ObjectID is the pen.
      class DrawCurve < Base
        include ShapeFlags

        TYPE = 0x4018

        class DrawCurveBody < Body
          endian :little
          mandatory_parameter :flags
          float :tension
          uint32 :offset
          uint32 :num_segments
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { false },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawCurveBody

        def pen_id = emf_object_id
        def tension = body.tension
        def start_point_index = body.offset
        def num_segments = body.num_segments
        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
