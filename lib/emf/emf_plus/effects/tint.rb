# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # TintEffect (2.2.3.11).
      class Tint < Effect
        GUID = "1077af00-2848-4441-9489-44ad4c2d7a2c"

        class TintBody < Records::Body
          endian :little
          int32 :hue
          int32 :amount
        end
        BODY = TintBody

        def hue = body.hue
        def amount = body.amount
      end
    end
  end
end
