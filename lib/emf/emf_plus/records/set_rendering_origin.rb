# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetRenderingOrigin (2.3.6.6). Flags are unused.
      class SetRenderingOrigin < Base
        TYPE = 0x401D

        class SetRenderingOriginBody < Body
          endian :little
          int32 :x
          int32 :y
        end
        BODY = SetRenderingOriginBody

        def x = body.x.to_i
        def y = body.y.to_i
      end
    end
  end
end
