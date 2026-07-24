# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class Rect
        def initialize(left:, top:, right:, bottom:)
          @left = left
          @top = top
          @right = right
          @bottom = bottom
        end

        attr_reader :left, :top, :right, :bottom

        def self.from_wire(wire)
          new(left: wire.left, top: wire.top, right: wire.right, bottom: wire.bottom)
        end

        def to_wire
          Binary::Types::RectL.new(left: left, top: top, right: right, bottom: bottom)
        end

        def width
          right - left
        end

        def height
          bottom - top
        end

        def empty?
          width <= 0 || height <= 0
        end

        def contains?(point)
          point.x.between?(left, right) && point.y.between?(top, bottom)
        end

        def ==(other)
          other.is_a?(self.class) &&
            left == other.left && top == other.top &&
            right == other.right && bottom == other.bottom
        end
        alias eql? ==

        def hash
          [self.class, left, top, right, bottom].hash
        end

        def inspect
          "#<#{self.class.name} left=#{left} top=#{top} right=#{right} bottom=#{bottom}>"
        end
      end
    end
  end
end
