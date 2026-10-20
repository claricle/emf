# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Effects
      # ColorMatrixEffect (2.2.3.6).
      class ColorMatrix < Effect
        GUID = "718f2615-7933-40e3-a511-5f68fe14dd74"

        class ColorMatrixBody < Records::Body
          endian :little
          array :matrix_values, type: :float32_le, initial_length: 25
        end
        BODY = ColorMatrixBody

        # Matrix[row][column]; the spec lists each column's five rows in turn.
        def matrix = Array.new(5) { |row| Array.new(5) { |column| body.matrix_values[(column * 5) + row] } }
      end
    end
  end
end
