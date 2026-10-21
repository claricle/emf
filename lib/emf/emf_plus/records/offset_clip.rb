# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      # EmfPlusOffsetClip (2.3.1.1): translates the clipping region by dx, dy.
      class OffsetClip < Base
        TYPE = 0x4035

        class OffsetClipBody < Body
          endian :little
          float32_le :dx
          float32_le :dy
        end
        BODY = OffsetClipBody

        def dx = body.dx
        def dy = body.dy
      end
    end
  end
end
