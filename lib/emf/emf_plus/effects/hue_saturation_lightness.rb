# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # HueSaturationLightnessEffect (2.2.3.7).
      class HueSaturationLightness < Effect
        GUID = "8b2dd6c3-eb07-4d87-a5f0-7108e26a9c5f"

        class HueSaturationLightnessBody < BinData::Record
          endian :little
          int32 :hue_level
          int32 :saturation_level
          int32 :lightness_level
        end
        BODY = HueSaturationLightnessBody

        def hue_level = body.hue_level
        def saturation_level = body.saturation_level
        def lightness_level = body.lightness_level
      end
    end
  end
end
