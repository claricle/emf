# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # ColorBalanceEffect (2.2.3.3).
      class ColorBalance < Effect
        GUID = "537e597d-251e-48da-9664-29ca496b70f8"

        class ColorBalanceBody < Records::Body
          endian :little
          int32 :cyan_red
          int32 :magenta_green
          int32 :yellow_blue
        end
        BODY = ColorBalanceBody

        def cyan_red = body.cyan_red
        def magenta_green = body.magenta_green
        def yellow_blue = body.yellow_blue
      end
    end
  end
end
