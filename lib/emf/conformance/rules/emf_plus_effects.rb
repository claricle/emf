# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

require_relative "emf_plus_common"

# EMF+ image rules (reading EmfPlusPayloads.completed_object at run time) over the decoded effect parameter blocks (MS-EMFPLUS 2.2.3) and
# the pixel data of a bitmap (2.2.2.2, 2.2.2.3). Only a "MUST be in the range" /
# "MUST be one of" clause is an error. A field whose text gives meaningful ranges
# in "SHOULD" terms (ColorCurve AdjustmentIntensity, ColorMatrix[4][4] = 1.0,
# SharpenEffect Radius, which has no stated range) is not checked.
module Emf
  module Conformance
    module EmfPlusEffects
      Effects = Emf::EmfPlus::Effects
      Records = Emf::EmfPlus::Records
      Objects = Emf::EmfPlus::Objects
      Support = EmfPlusSupport

      CURVE_ADJUSTMENTS = (0..7) # CurveAdjustments (2.1.1.7), AdjustExposure..AdjustBlackSaturation
      CURVE_CHANNELS = (0..3) # CurveChannel (2.1.1.8)
      BITS_PER_PIXEL_SHIFT = 8

      # effect class => [[reader, allowed range, label], ...]; each range is a MUST (or a defined value table) of 2.2.3.x.
      RANGES = {
        Effects::Blur => [[:blur_radius, 0.0..255.0, "BlurRadius"], [:expand_edge, 0..1, "ExpandEdge"]],
        Effects::BrightnessContrast => [[:brightness_level, -255..255, "BrightnessLevel"],
                                        [:contrast_level, -100..100, "ContrastLevel"]],
        Effects::ColorBalance => [[:cyan_red, -100..100, "CyanRed"], [:magenta_green, -100..100, "MagentaGreen"],
                                  [:yellow_blue, -100..100, "YellowBlue"]],
        Effects::ColorCurve => [[:curve_adjustment, CURVE_ADJUSTMENTS, "CurveAdjustment"],
                                [:curve_channel, CURVE_CHANNELS, "CurveChannel"]],
        Effects::HueSaturationLightness => [[:hue_level, -180..180, "HueLevel"],
                                            [:saturation_level, -100..100, "SaturationLevel"],
                                            [:lightness_level, -100..100, "LightnessLevel"]],
        Effects::Levels => [[:highlight, 0..100, "Highlight"], [:mid_tone, -100..100, "MidTone"],
                            [:shadow, 0..100, "Shadow"]],
        Effects::Sharpen => [[:amount, 0.0..100.0, "Amount"]],
        Effects::Tint => [[:hue, -180..180, "Hue"], [:amount, -100..100, "Amount"]]
      }.freeze

      module_function

      def effect_parameters(located)
        record = located.record
        return unless record.is_a?(Records::SerializableObject) && Effects.lookup(record.object_guid)

        effect = record.effect
        problems = RANGES.find { |klass, _| effect.is_a?(klass) }&.last.to_a.filter_map do |reader, range, label|
          value = effect.public_send(reader)
          "#{label} #{value} is outside #{range.first}..#{range.last}" unless range.cover?(value)
        end
        problems.concat(color_matrix_problems(effect)) if effect.is_a?(Effects::ColorMatrix)
        problems.map { |problem| "#{effect.class.name.split('::').last} effect (#{record.object_guid}) #{problem}" }
      rescue Emf::ParseError
        nil # reported by emfplus.object.serializable_buffer
      end

      # Matrix_4_0 .. Matrix_4_3 MUST be 0.0 (2.2.3.6).
      def color_matrix_problems(effect)
        effect.matrix[4].first(4).each_with_index.filter_map do |value, column|
          "Matrix[4][#{column}] is #{value}, MUST be 0.0" unless value.zero?
        end
      end

      # Decoded bitmaps of the object this record completes.
      def pixel_data(stream, located)
        logical = EmfPlusPayloads.completed_object(stream, located)
        return unless logical&.object_type == Objects::IMAGE

        bitmap = logical.body.bitmap
        return unless bitmap&.bitmap_type&.zero?

        pixel_problems(bitmap).map { |problem| "EmfPlusImage (object ID #{logical.emf_object_id}) bitmap #{problem}" }
      rescue Emf::ParseError
        nil # reported by emfplus.object.payload
      end

      # Stride is bytes per pixel times Width (2.2.2.2), so a scan-line is at least ceil(Width * bits / 8)
      # bytes; PixelData holds Height scan-lines of Stride bytes (2.2.2.3).
      def pixel_problems(bitmap)
        bits = (bitmap.pixel_format >> BITS_PER_PIXEL_SHIFT) & 0xFF
        row = ((bitmap.width * bits) + 7) / 8
        problems = []
        if bitmap.stride < row
          problems << "Stride #{bitmap.stride} is smaller than the #{row} bytes of a #{bitmap.width}-pixel scan-line " \
                      "at #{bits} bits per pixel"
        end
        needed = bitmap.stride.abs * bitmap.height.abs
        have = bitmap.bitmap_data.pixel_data.to_s.bytesize
        problems << "PixelData holds #{have} bytes, Stride #{bitmap.stride} * Height #{bitmap.height} needs #{needed}" if have < needed
        problems
      end
    end

    EmfPlusSupport.per_record(id: "emfplus.object.effect_parameters", citation: "MS-EMFPLUS 2.2.3",
                              kind: :effect_parameters) { |located| EmfPlusEffects.effect_parameters(located) }

    Registry.loading.register(id: "emfplus.image.pixel_data", formats: [:emf_plus], citation: "MS-EMFPLUS 2.2.2.3",
                              kind: :pixel_data, tolerant_reason: nil) do |context|
      EmfPlusPayloads.per_object(context) { |stream, located| EmfPlusEffects.pixel_data(stream, located) }
    end
  end
end
