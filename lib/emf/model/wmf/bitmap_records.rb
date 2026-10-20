# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class BitBlt < Record
          def initialize(raster_operation:, source_y:, source_x:, height:, width:, destination_y:, destination_x:, bitmap: nil,
                         reserved: 0, suffix: "".b, offset: nil, type_id: 0x0922)
            super(type_id: type_id, offset: offset)
            @raster_operation = raster_operation
            @source_y = source_y
            @source_x = source_x
            @height = height
            @width = width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @reserved = reserved
            @suffix = suffix
          end

          attr_accessor :raster_operation, :source_y, :source_x, :height, :width, :destination_y, :destination_x, :bitmap, :reserved,
                        :suffix
        end

        class DibBitBlt < Record
          def initialize(raster_operation:, source_y:, source_x:, height:, width:, destination_y:, destination_x:, bitmap: nil,
                         reserved: 0, suffix: "".b, offset: nil, type_id: 0x0940)
            super(type_id: type_id, offset: offset)
            @raster_operation = raster_operation
            @source_y = source_y
            @source_x = source_x
            @height = height
            @width = width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @reserved = reserved
            @suffix = suffix
          end

          attr_accessor :raster_operation, :source_y, :source_x, :height, :width, :destination_y, :destination_x, :bitmap, :reserved,
                        :suffix
        end

        class StretchBlt < Record
          def initialize(raster_operation:, source_height:, source_width:, source_y:, source_x:, destination_height:,
                         destination_width:, destination_y:, destination_x:, bitmap: nil, reserved: 0, suffix: "".b, offset: nil,
                         type_id: 0x0B23)
            super(type_id: type_id, offset: offset)
            @raster_operation = raster_operation
            @source_height = source_height
            @source_width = source_width
            @source_y = source_y
            @source_x = source_x
            @destination_height = destination_height
            @destination_width = destination_width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @reserved = reserved
            @suffix = suffix
          end

          attr_accessor :raster_operation, :source_height, :source_width, :source_y, :source_x, :destination_height, :destination_width,
                        :destination_y, :destination_x, :bitmap, :reserved, :suffix
        end

        class DibStretchBlt < Record
          def initialize(raster_operation:, source_height:, source_width:, source_y:, source_x:, destination_height:,
                         destination_width:, destination_y:, destination_x:, bitmap: nil, reserved: 0, suffix: "".b, offset: nil,
                         type_id: 0x0B41)
            super(type_id: type_id, offset: offset)
            @raster_operation = raster_operation
            @source_height = source_height
            @source_width = source_width
            @source_y = source_y
            @source_x = source_x
            @destination_height = destination_height
            @destination_width = destination_width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @reserved = reserved
            @suffix = suffix
          end

          attr_accessor :raster_operation, :source_height, :source_width, :source_y, :source_x, :destination_height, :destination_width,
                        :destination_y, :destination_x, :bitmap, :reserved, :suffix
        end

        class SetDibToDev < Record
          def initialize(color_usage:, scan_count:, start_scan:, source_y:, source_x:, height:, width:, destination_y:,
                         destination_x:, bitmap:, suffix: "".b, offset: nil, type_id: 0x0D33)
            super(type_id: type_id, offset: offset)
            @color_usage = color_usage
            @scan_count = scan_count
            @start_scan = start_scan
            @source_y = source_y
            @source_x = source_x
            @height = height
            @width = width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @suffix = suffix
          end

          attr_accessor :color_usage, :scan_count, :start_scan, :source_y, :source_x, :height, :width, :destination_y, :destination_x,
                        :bitmap, :suffix
        end

        class StretchDib < Record
          def initialize(raster_operation:, color_usage:, source_height:, source_width:, source_y:, source_x:, destination_height:,
                         destination_width:, destination_y:, destination_x:, bitmap:, suffix: "".b, offset: nil, type_id: 0x0F43)
            super(type_id: type_id, offset: offset)
            @raster_operation = raster_operation
            @color_usage = color_usage
            @source_height = source_height
            @source_width = source_width
            @source_y = source_y
            @source_x = source_x
            @destination_height = destination_height
            @destination_width = destination_width
            @destination_y = destination_y
            @destination_x = destination_x
            @bitmap = bitmap
            @suffix = suffix
          end

          attr_accessor :raster_operation, :color_usage, :source_height, :source_width, :source_y, :source_x, :destination_height,
                        :destination_width, :destination_y, :destination_x, :bitmap, :suffix
        end
      end
    end
  end
end
