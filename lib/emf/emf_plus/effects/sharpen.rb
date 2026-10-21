# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Effects
      # SharpenEffect (2.2.3.10).
      class Sharpen < Effect
        GUID = "63cbf3ee-c526-402c-8f71-62c540bf5142"

        class SharpenBody < Records::Body
          endian :little
          float32_le :radius
          float32_le :amount
        end
        BODY = SharpenBody

        def radius = body.radius
        def amount = body.amount
      end
    end
  end
end
