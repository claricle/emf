# frozen_string_literal: true

require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawBeziers (2.3.4.3). C compressed, P relative points; ObjectID is the pen.
      class DrawBeziers < Base
        include ShapeFlags

        TYPE = 0x4019

        class DrawBeziersBody < BinData::Record
          endian :little
          mandatory_parameter :flags
          uint32 :item_count
          point_array :point_data,
                      point_count: :item_count,
                      relative: -> { flags.anybits?(ShapeFlags::RELATIVE_FLAG) },
                      compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawBeziersBody

        def pen_id = emf_object_id
        def count = body.item_count
        def points = body.point_data.points
      end
    end
  end
end
