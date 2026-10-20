# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class Record < Emf::Model::Record
          Emf::Model::Visitor.register_visit(:visit_wmf_record, self)

          def initialize(type_id:, offset: nil)
            super()
            @type_id = type_id
            @offset = offset
          end

          attr_reader :type_id, :offset

          def accept(visitor)
            visitor.visit_wmf_record(self)
          end
        end

        class Eof < Record
          def initialize(offset: nil)
            super(type_id: 0, offset: offset)
          end
        end

        class PointRecord < Record
          WIRE_FIELDS = %i[y x].freeze

          def initialize(type_id:, x:, y:, offset: nil)
            super(type_id: type_id, offset: offset)
            @x = x
            @y = y
          end

          attr_accessor :x, :y
        end

        class MoveTo < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x0214)
            super
          end
        end

        class LineTo < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x0213)
            super
          end
        end

        class SetWindowOrg < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x020B)
            super
          end
        end

        class SetWindowExt < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x020C)
            super
          end
        end

        class SetViewportOrg < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x020D)
            super
          end
        end

        class SetViewportExt < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x020E)
            super
          end
        end

        class OffsetRecord < Record
          WIRE_FIELDS = %i[y_offset x_offset].freeze

          def initialize(type_id:, x_offset:, y_offset:, offset: nil)
            super(type_id: type_id, offset: offset)
            @x_offset = x_offset
            @y_offset = y_offset
          end

          attr_accessor :x_offset, :y_offset
        end

        class OffsetWindowOrg < OffsetRecord
          def initialize(x_offset:, y_offset:, offset: nil, type_id: 0x020F)
            super
          end
        end

        class OffsetViewportOrg < OffsetRecord
          def initialize(x_offset:, y_offset:, offset: nil, type_id: 0x0211)
            super
          end
        end

        class RectangleRecord < Record
          WIRE_FIELDS = %i[bottom right top left].freeze

          def initialize(type_id:, left:, top:, right:, bottom:, offset: nil)
            super(type_id: type_id, offset: offset)
            @left = left
            @top = top
            @right = right
            @bottom = bottom
          end

          attr_accessor :left, :top, :right, :bottom
        end

        class Rectangle < RectangleRecord
          def initialize(left:, top:, right:, bottom:, offset: nil, type_id: 0x041B)
            super
          end
        end

        class Ellipse < RectangleRecord
          def initialize(left:, top:, right:, bottom:, offset: nil, type_id: 0x0418)
            super
          end
        end

        class Arc < RectangleRecord
          WIRE_FIELDS = %i[y_end_arc x_end_arc y_start_arc x_start_arc bottom right top left].freeze

          def initialize(left:, top:, right:, bottom:, x_start_arc:, y_start_arc:, x_end_arc:, y_end_arc:,
                         offset: nil, type_id: 0x0817)
            super(type_id: type_id, offset: offset, left: left, top: top, right: right, bottom: bottom)
            @x_start_arc = x_start_arc
            @y_start_arc = y_start_arc
            @x_end_arc = x_end_arc
            @y_end_arc = y_end_arc
          end

          attr_accessor :x_start_arc, :y_start_arc, :x_end_arc, :y_end_arc
        end

        class RadialRecord < RectangleRecord
          WIRE_FIELDS = %i[y_radial2 x_radial2 y_radial1 x_radial1 bottom right top left].freeze

          def initialize(type_id:, left:, top:, right:, bottom:, x_radial1:, y_radial1:, x_radial2:, y_radial2:, offset: nil)
            super(type_id: type_id, offset: offset, left: left, top: top, right: right, bottom: bottom)
            @x_radial1 = x_radial1
            @y_radial1 = y_radial1
            @x_radial2 = x_radial2
            @y_radial2 = y_radial2
          end

          attr_accessor :x_radial1, :y_radial1, :x_radial2, :y_radial2
        end

        class Pie < RadialRecord
          def initialize(left:, top:, right:, bottom:, x_radial1:, y_radial1:, x_radial2:, y_radial2:,
                         offset: nil, type_id: 0x081A)
            super
          end
        end

        class Chord < RadialRecord
          def initialize(left:, top:, right:, bottom:, x_radial1:, y_radial1:, x_radial2:, y_radial2:,
                         offset: nil, type_id: 0x0830)
            super
          end
        end

        class RoundRect < RectangleRecord
          WIRE_FIELDS = %i[height width bottom right top left].freeze

          def initialize(left:, top:, right:, bottom:, width:, height:, offset: nil, type_id: 0x061C)
            super(type_id: type_id, offset: offset, left: left, top: top, right: right, bottom: bottom)
            @width = width
            @height = height
          end

          attr_accessor :width, :height
        end

        PointS = Struct.new(:x, :y, keyword_init: true)

        class PointArrayRecord < Record
          def initialize(type_id:, points:, offset: nil)
            super(type_id: type_id, offset: offset)
            @points = points
          end

          attr_accessor :points
        end

        class Polygon < PointArrayRecord
          def initialize(points:, offset: nil, type_id: 0x0324)
            super
          end
        end

        class Polyline < PointArrayRecord
          def initialize(points:, offset: nil, type_id: 0x0325)
            super
          end
        end

        class PolyPolygon < PointArrayRecord
          def initialize(points:, points_per_polygon:, offset: nil, type_id: 0x0538)
            super(points: points, offset: offset, type_id: type_id)
            @points_per_polygon = points_per_polygon
          end

          attr_accessor :points_per_polygon
        end

        class UnknownRecord < Record
          def initialize(type_id:, raw_bytes:, offset: nil)
            super(type_id: type_id, offset: offset)
            @raw_bytes = raw_bytes.dup.freeze
          end

          attr_reader :raw_bytes
        end
      end
    end
  end
end

require "emf/model/wmf/object_records"
require "emf/model/wmf/font_record"
require "emf/model/wmf/text_records"
require "emf/model/wmf/state_records"
require "emf/model/wmf/palette_records"
