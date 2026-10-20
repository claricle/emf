# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        RegionBounds = Struct.new(:left, :top, :right, :bottom, keyword_init: true)
        RegionScanLine = Struct.new(:left, :right, keyword_init: true)
        RegionScan = Struct.new(:top, :bottom, :lines, keyword_init: true)

        class CreateRegion < ObjectRecord
          def initialize(next_in_chain:, object_count:, bounds:, scans:, offset: nil, suffix: "".b, type_id: 0x06FF)
            super(type_id: type_id, offset: offset)
            @next_in_chain = next_in_chain
            @object_count = object_count
            @bounds = bounds
            @scans = scans
            @suffix = suffix
          end

          attr_accessor :next_in_chain, :object_count, :bounds, :scans, :suffix
        end

        class FillRegion < ObjectRecord
          WIRE_FIELDS = %i[region_index brush_index].freeze
          WIRE_TYPES = %i[uint16 uint16].freeze
          WIRE_FORMAT = "v2"

          def initialize(region_index:, brush_index:, offset: nil, suffix: "".b, type_id: 0x0228)
            super(type_id: type_id, offset: offset)
            @region_index = region_index
            @brush_index = brush_index
            @suffix = suffix
          end

          attr_accessor :region_index, :brush_index, :suffix
        end

        class FrameRegion < FillRegion
          WIRE_FIELDS = %i[region_index brush_index height width].freeze
          WIRE_TYPES = %i[uint16 uint16 int16 int16].freeze
          WIRE_FORMAT = "v2s<2"

          def initialize(region_index:, brush_index:, height:, width:, offset: nil, suffix: "".b, type_id: 0x0429)
            super(region_index: region_index, brush_index: brush_index, offset: offset, suffix: suffix, type_id: type_id)
            @height = height
            @width = width
          end

          attr_accessor :height, :width
        end

        class RegionReference < ObjectReference
          def initialize(type_id:, object_index:, offset: nil, suffix: "".b)
            super(type_id: type_id, object_index: object_index, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class InvertRegion < RegionReference
          def initialize(object_index:, offset: nil, suffix: "".b, type_id: 0x012A)
            super
          end
        end

        class PaintRegion < RegionReference
          def initialize(object_index:, offset: nil, suffix: "".b, type_id: 0x012B)
            super
          end
        end

        class SelectClipRegion < RegionReference
          def initialize(object_index:, offset: nil, suffix: "".b, type_id: 0x012C)
            super
          end
        end

        class OffsetClipRgn < OffsetRecord
          WIRE_TYPES = %i[int16 int16].freeze
          WIRE_FORMAT = "s<2"

          def initialize(x_offset:, y_offset:, offset: nil, suffix: "".b, type_id: 0x0220)
            super(type_id: type_id, x_offset: x_offset, y_offset: y_offset, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class ExcludeClipRect < RectangleRecord
          WIRE_TYPES = %i[int16 int16 int16 int16].freeze
          WIRE_FORMAT = "s<4"

          def initialize(left:, top:, right:, bottom:, offset: nil, suffix: "".b, type_id: 0x0415)
            super(type_id: type_id, left: left, top: top, right: right, bottom: bottom, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class IntersectClipRect < ExcludeClipRect
          def initialize(left:, top:, right:, bottom:, offset: nil, suffix: "".b, type_id: 0x0416)
            super
          end
        end
      end
    end
  end
end
