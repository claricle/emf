# frozen_string_literal: true

module Emf
  module EmfPlus
    # Typed image effect parameter blocks (2.2.3), identified by the GUID of
    # the EmfPlusSerializableObject that carries them.
    module Effects
      autoload :Effect, "emf/emf_plus/effects/effect"
      autoload :Opaque, "emf/emf_plus/effects/opaque"
      autoload :Blur, "emf/emf_plus/effects/blur"
      autoload :BrightnessContrast, "emf/emf_plus/effects/brightness_contrast"
      autoload :ColorBalance, "emf/emf_plus/effects/color_balance"
      autoload :ColorCurve, "emf/emf_plus/effects/color_curve"
      autoload :ColorLookupTable, "emf/emf_plus/effects/color_lookup_table"
      autoload :ColorMatrix, "emf/emf_plus/effects/color_matrix"
      autoload :HueSaturationLightness, "emf/emf_plus/effects/hue_saturation_lightness"
      autoload :Levels, "emf/emf_plus/effects/levels"
      autoload :RedEyeCorrection, "emf/emf_plus/effects/red_eye_correction"
      autoload :Sharpen, "emf/emf_plus/effects/sharpen"
      autoload :Tint, "emf/emf_plus/effects/tint"

      CLASSES = %i[Blur BrightnessContrast ColorBalance ColorCurve ColorLookupTable ColorMatrix
                   HueSaturationLightness Levels RedEyeCorrection Sharpen Tint].freeze
      private_constant :CLASSES

      module_function

      # `serializable` is a Records::SerializableObject.
      def decode(serializable)
        klass = lookup(serializable.object_guid)
        return Opaque.new(serializable.buffer) unless klass

        klass.new(serializable.buffer, offset: serializable.offset, record_code: serializable.type)
      rescue ParseError
        raise unless klass == ColorCurve

        Opaque.new(serializable.buffer)
      end

      def lookup(guid)
        CLASSES.map { |name| const_get(name) }.find { |klass| guid == klass::GUID }
      end
    end
  end
end
