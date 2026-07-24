# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      class Matrix
        IDENTITY = {
          m11: 1.0, m12: 0.0, m21: 0.0, m22: 1.0, dx: 0.0, dy: 0.0
        }.freeze

        def initialize(m11:, m12:, m21:, m22:, dx:, dy:)
          @m11 = m11.to_f
          @m12 = m12.to_f
          @m21 = m21.to_f
          @m22 = m22.to_f
          @dx = dx.to_f
          @dy = dy.to_f
        end

        attr_reader :m11, :m12, :m21, :m22, :dx, :dy

        def self.from_wire(wire)
          new(m11: wire.m11, m12: wire.m12, m21: wire.m21, m22: wire.m22, dx: wire.dx, dy: wire.dy)
        end

        def to_wire
          Binary::Types::XForm.new(m11: m11, m12: m12, m21: m21, m22: m22, dx: dx, dy: dy)
        end

        def self.identity
          new(**IDENTITY)
        end

        def identity?
          m11 == 1.0 && m12 == 0.0 && m21 == 0.0 && m22 == 1.0 && dx == 0.0 && dy == 0.0
        end

        def ==(other)
          other.is_a?(self.class) &&
            m11 == other.m11 && m12 == other.m12 &&
            m21 == other.m21 && m22 == other.m22 &&
            dx == other.dx && dy == other.dy
        end
        alias eql? ==

        def hash
          [self.class, m11, m12, m21, m22, dx, dy].hash
        end
      end
    end
  end
end
