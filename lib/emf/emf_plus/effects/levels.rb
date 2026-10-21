# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # LevelsEffect (2.2.3.8).
      class Levels < Effect
        GUID = "99c354ec-2a31-4f3a-8c34-17a803b33a25"

        class LevelsBody < Records::Body
          endian :little
          int32 :highlight
          int32 :mid_tone
          int32 :shadow
        end
        BODY = LevelsBody

        def highlight = body.highlight
        def mid_tone = body.mid_tone
        def shadow = body.shadow
      end
    end
  end
end
