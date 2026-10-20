# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # BlurEffect (2.2.3.1).
      class Blur < Effect
        GUID = "633c80a4-1843-482b-9ef2-be2834c5fdd4"

        class BlurBody < Records::Body
          endian :little
          float :blur_radius
          uint32 :expand_edge
        end
        BODY = BlurBody

        def blur_radius = body.blur_radius
        def expand_edge = body.expand_edge
      end
    end
  end
end
