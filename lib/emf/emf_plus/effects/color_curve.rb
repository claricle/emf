# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # ColorCurveEffect (2.2.3.4).
      class ColorCurve < Effect
        GUID = "dd6a0022-58e4-4a67-9d9b-d48eb881a53d"

        class ColorCurveBody < BinData::Record
          endian :little
          uint32 :curve_adjustment
          uint32 :curve_channel
          int32 :adjustment_intensity
        end
        BODY = ColorCurveBody

        def curve_adjustment = body.curve_adjustment
        def curve_channel = body.curve_channel
        def adjustment_intensity = body.adjustment_intensity
      end
    end
  end
end
