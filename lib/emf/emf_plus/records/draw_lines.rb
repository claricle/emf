# frozen_string_literal: true

require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawLines (2.3.4.10). C compressed, L closes the shape, P relative points; ObjectID is the pen.
      class DrawLines < Base
        include ShapeFlags

        TYPE = 0x400D

        class DrawLinesBody < BinData::Record
          endian :little
          mandatory_parameter :flags
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { flags.anybits?(ShapeFlags::RELATIVE_FLAG) },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawLinesBody

        def pen_id = emf_object_id
        def flag_fields = super.merge(close_shape: 0x2000)

        def close_shape? = flags.anybits?(0x2000)
        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
