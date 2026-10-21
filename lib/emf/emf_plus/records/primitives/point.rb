# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPoint (2.2.2.35): 16-bit signed, the "compressed" form.
        class Point < Body
          endian :little
          int16 :x
          int16 :y
        end
      end
    end
  end
end
