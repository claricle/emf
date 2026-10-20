# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class GeometryRecord < Record
          def initialize(type_id:, offset: nil, suffix: "".b)
            super(type_id: type_id, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class ScaleExtRecord < GeometryRecord
          WIRE_FIELDS = %i[y_denom y_num x_denom x_num].freeze
          WIRE_TYPES = %i[int16 int16 int16 int16].freeze
          WIRE_FORMAT = "s<4"
          PAYLOAD_BYTES = 8

          def initialize(type_id:, y_denom:, y_num:, x_denom:, x_num:, offset: nil, suffix: "".b)
            super(type_id: type_id, offset: offset, suffix: suffix)
            @y_denom = y_denom
            @y_num = y_num
            @x_denom = x_denom
            @x_num = x_num
          end

          attr_accessor :y_denom, :y_num, :x_denom, :x_num
        end

        class ScaleWindowExt < ScaleExtRecord
          def initialize(y_denom:, y_num:, x_denom:, x_num:, offset: nil, suffix: "".b, type_id: 0x0410)
            super
          end
        end

        class ScaleViewportExt < ScaleExtRecord
          def initialize(y_denom:, y_num:, x_denom:, x_num:, offset: nil, suffix: "".b, type_id: 0x0412)
            super
          end
        end

        class ColorPointRecord < GeometryRecord
          WIRE_FIELDS = %i[color y x].freeze
          WIRE_TYPES = %i[uint32 int16 int16].freeze
          WIRE_FORMAT = "Vs<2"
          PAYLOAD_BYTES = 8

          def initialize(type_id:, color:, y:, x:, offset: nil, suffix: "".b)
            super(type_id: type_id, offset: offset, suffix: suffix)
            @color = color
            @y = y
            @x = x
          end

          attr_accessor :color, :y, :x
        end

        class FloodFill < ColorPointRecord
          def initialize(color:, y:, x:, offset: nil, suffix: "".b, type_id: 0x0419)
            super
          end
        end

        class SetPixel < ColorPointRecord
          def initialize(color:, y:, x:, offset: nil, suffix: "".b, type_id: 0x041F)
            super
          end
        end

        class ExtFloodFill < ColorPointRecord
          WIRE_FIELDS = %i[mode color y x].freeze
          WIRE_TYPES = %i[uint16 uint32 int16 int16].freeze
          WIRE_FORMAT = "vVs<2"
          PAYLOAD_BYTES = 10

          def initialize(mode:, color:, y:, x:, offset: nil, suffix: "".b, type_id: 0x0548)
            super(type_id: type_id, color: color, y: y, x: x, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class PatBlt < GeometryRecord
          WIRE_FIELDS = %i[raster_operation height width y_left x_left].freeze
          WIRE_TYPES = %i[uint32 int16 int16 int16 int16].freeze
          WIRE_FORMAT = "Vs<4"
          PAYLOAD_BYTES = 12

          def initialize(raster_operation:, height:, width:, y_left:, x_left:, offset: nil, suffix: "".b, type_id: 0x061D)
            super(type_id: type_id, offset: offset, suffix: suffix)
            @raster_operation = raster_operation
            @height = height
            @width = width
            @y_left = y_left
            @x_left = x_left
          end

          attr_accessor :raster_operation, :height, :width, :y_left, :x_left
        end
      end
    end
  end
end
