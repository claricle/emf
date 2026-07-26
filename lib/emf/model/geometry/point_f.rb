# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class PointF
        def initialize(x:, y:)
          @x = x.to_f
          @y = y.to_f
        end

        attr_reader :x, :y

        def self.from_wire(wire)
          new(x: wire.x, y: wire.y)
        end

        def to_wire
          Binary::Types::PointD.new(x: x, y: y)
        end

        def ==(other)
          other.is_a?(self.class) && x == other.x && y == other.y
        end
        alias eql? ==

        def hash
          [self.class, x, y].hash
        end
      end
    end
  end
end
