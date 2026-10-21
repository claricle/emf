# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class Color
        # One instantiated ColorRef and its field slots, built on first use.
        module WireTemplate
          module_function

          def get
            @get ||= begin
              sample = Binary::Types::ColorRef.new
              sample.field_names.each { |name| sample.public_send(name) }
              [sample, Emf::Emr::Binary::WireCopy.slots(sample)].freeze
            end
          end
        end
        private_constant :WireTemplate

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

        # Same ColorRef as `ColorRef.new(red:, green:, blue:, reserved:)`,
        # built from a copy of one instantiated ColorRef instead of BinData's
        # lazy construction (the record builders call this once per color).
        def to_wire
          template, slots = WireTemplate.get
          Emf::Emr::Binary::WireCopy.build(template, slots, { red: red, green: green, blue: blue, reserved: alpha })
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
