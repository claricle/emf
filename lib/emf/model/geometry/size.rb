# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class Size
        def initialize(cx:, cy:)
          @cx = cx
          @cy = cy
        end

        attr_reader :cx, :cy

        def self.from_wire(wire)
          new(cx: wire.cx, cy: wire.cy)
        end

        def to_wire
          Binary::Types::SizeL.new(cx: cx, cy: cy)
        end

        def ==(other)
          other.is_a?(self.class) && cx == other.cx && cy == other.cy
        end
        alias eql? ==

        def hash
          [self.class, cx, cy].hash
        end
      end
    end
  end
end
