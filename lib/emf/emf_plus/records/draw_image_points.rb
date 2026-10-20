# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_f"
require "emf/emf_plus/records/primitives/point_f"
require "emf/emf_plus/records/primitives/point"
require "emf/emf_plus/records/primitives/point_r"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawImagePoints (2.3.4.9). P selects relative EmfPlusPointR
      # elements and makes C undefined; otherwise C selects EmfPlusPoint over
      # EmfPlusPointF. E means an earlier EmfPlusSerializableObject supplies
      # the effect.
      class DrawImagePoints < Base
        TYPE = 0x401B
        COMPRESSED_FLAG = 0x4000
        EFFECT_FLAG = 0x2000
        RELATIVE_FLAG = 0x0800
        OBJECT_ID_MASK = 0x00FF

        class DrawImagePointsBody < BinData::Record
          endian :little
          mandatory_parameter :flags
          uint32 :image_attributes_id
          int32 :src_unit
          rect_f :src_rect
          uint32 :point_count
          array :relative_points, type: :point_r, initial_length: :point_count, onlyif: -> { flags.anybits?(RELATIVE_FLAG) }
          array :compressed_points, type: :point, initial_length: :point_count,
                                    onlyif: -> { !flags.anybits?(RELATIVE_FLAG) && flags.anybits?(COMPRESSED_FLAG) }
          array :float_points, type: :point_f, initial_length: :point_count,
                               onlyif: -> { !flags.anybits?(RELATIVE_FLAG) && !flags.anybits?(COMPRESSED_FLAG) }
        end
        BODY = DrawImagePointsBody

        def flag_fields
          { compressed: COMPRESSED_FLAG, relative: RELATIVE_FLAG, effect: EFFECT_FLAG, image_object_id: OBJECT_ID_MASK }
        end

        def relative? = flags.anybits?(RELATIVE_FLAG)
        def compressed? = !relative? && flags.anybits?(COMPRESSED_FLAG)
        def effect? = flags.anybits?(EFFECT_FLAG)
        def image_object_id = flags & OBJECT_ID_MASK
        def image_attributes_id = body.image_attributes_id
        def src_unit = body.src_unit
        def src_rect = body.src_rect.then { |r| [r.x, r.y, r.width, r.height] }
        def count = body.point_count
        def points = relative? ? body.relative_points.map { |p| [p.x.to_i, p.y.to_i] } : point_array.map { |p| [p.x, p.y] }

        private

        def point_array
          compressed? ? body.compressed_points : body.float_points
        end
      end
    end
  end
end
