# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # BrightnessContrastEffect (2.2.3.2).
      class BrightnessContrast < Effect
        GUID = "d3a1dbe1-8ec4-4c17-9f4c-ea97ad1c343d"

        class BrightnessContrastBody < BinData::Record
          endian :little
          int32 :brightness_level
          int32 :contrast_level
        end
        BODY = BrightnessContrastBody

        def brightness_level = body.brightness_level
        def contrast_level = body.contrast_level
      end
    end
  end
end
