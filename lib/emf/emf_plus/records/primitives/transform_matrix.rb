# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusTransformMatrix (2.2.2.47): m11, m12, m21, m22, dx, dy.
        class TransformMatrix < BinData::Record
          endian :little
          float :m11
          float :m12
          float :m21
          float :m22
          float :dx
          float :dy
        end
      end
    end
  end
end
