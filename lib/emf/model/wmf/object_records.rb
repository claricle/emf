# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class ObjectRecord < Record
        end

        class CreatePenIndirect < ObjectRecord
          WIRE_FIELDS = %i[pen_style width_x width_y color_ref].freeze
          WIRE_FORMAT = "vs<2V"
          WIRE_TYPES = %i[uint16 int16 int16 uint32].freeze
          PAYLOAD_BYTES = 10

          def initialize(pen_style:, width_x:, width_y:, color_ref:, offset: nil, type_id: 0x02FA)
            super(type_id: type_id, offset: offset)
            @pen_style = pen_style
            @width_x = width_x
            @width_y = width_y
            @color_ref = color_ref
          end

          attr_accessor :pen_style, :width_x, :width_y, :color_ref
        end

        class CreateBrushIndirect < ObjectRecord
          WIRE_FIELDS = %i[brush_style color_ref brush_hatch].freeze
          WIRE_FORMAT = "vVv"
          WIRE_TYPES = %i[uint16 uint32 uint16].freeze
          PAYLOAD_BYTES = 8

          def initialize(brush_style:, color_ref:, brush_hatch:, offset: nil, type_id: 0x02FC)
            super(type_id: type_id, offset: offset)
            @brush_style = brush_style
            @color_ref = color_ref
            @brush_hatch = brush_hatch
          end

          attr_accessor :brush_style, :color_ref, :brush_hatch
        end

        class ObjectReference < ObjectRecord
          WIRE_FIELDS = %i[object_index].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(type_id:, object_index:, offset: nil)
            super(type_id: type_id, offset: offset)
            @object_index = object_index
          end

          attr_accessor :object_index
        end

        class SelectObject < ObjectReference
          def initialize(object_index:, offset: nil, type_id: 0x012D)
            super
          end
        end

        class DeleteObject < ObjectReference
          def initialize(object_index:, offset: nil, type_id: 0x01F0)
            super
          end
        end
      end
    end
  end
end
