# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class Color
        def initialize(red:, green:, blue:, alpha: 255)
          @red = coerce(red)
          @green = coerce(green)
          @blue = coerce(blue)
          @alpha = coerce(alpha)
        end

        attr_reader :red, :green, :blue, :alpha

        def self.from_wire(wire)
          new(red: wire.red, green: wire.green, blue: wire.blue, alpha: wire.reserved.zero? ? 255 : wire.reserved)
        end

        def to_wire
          Binary::Types::ColorRef.new(red: red, green: green, blue: blue, reserved: alpha)
        end

        def to_hex
          alpha == 255 ? format("#%02X%02X%02X", red, green, blue) : to_hex_rgba
        end

        def to_hex_rgba
          format("#%02X%02X%02X%02X", red, green, blue, alpha)
        end

        def self.black
          new(red: 0, green: 0, blue: 0)
        end

        def self.white
          new(red: 255, green: 255, blue: 255)
        end

        def self.transparent
          new(red: 0, green: 0, blue: 0, alpha: 0)
        end

        def ==(other)
          other.is_a?(self.class) &&
            red == other.red && green == other.green &&
            blue == other.blue && alpha == other.alpha
        end
        alias eql? ==

        def hash
          [self.class, red, green, blue, alpha].hash
        end

        def inspect
          "#<#{self.class.name} #{to_hex_rgba}>"
        end

        private

        def coerce(value)
          Integer(value)
        end
      end
    end
  end
end
