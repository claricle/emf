# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRect (2.2.2.39): 16-bit signed, the "compressed" form.
        class Rect < BinData::Record
          endian :little
          int16 :x
          int16 :y
          int16 :width
          int16 :height
        end
      end
    end
  end
end
