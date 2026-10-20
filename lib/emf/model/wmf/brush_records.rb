# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class CreatePatternBrush < Record
          def initialize(bitmap_type:, width:, height:, width_bytes:, planes:, bits_pixel:, bits:, reserved:, pattern:,
                         offset: nil, suffix: "".b, type_id: 0x01F9)
            super(type_id: type_id, offset: offset)
            @bitmap_type = bitmap_type
            @width = width
            @height = height
            @width_bytes = width_bytes
            @planes = planes
            @bits_pixel = bits_pixel
            @bits = bits
            @reserved = reserved
            @pattern = pattern
            @suffix = suffix
          end

          attr_accessor :bitmap_type, :width, :height, :width_bytes, :planes, :bits_pixel, :bits, :reserved, :pattern, :suffix
        end

        class DibCreatePatternBrush < Record
          def initialize(style:, color_usage:, target:, offset: nil, type_id: 0x0142)
            super(type_id: type_id, offset: offset)
            @style = style
            @color_usage = color_usage
            @target = target
          end

          attr_accessor :style, :color_usage, :target
        end
      end
    end
  end
end
