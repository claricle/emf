# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

require_relative "emf_plus_common"

# EMF+ property, clip combine-mode and page-unit rules: enum domains and ranges
# of values the public records decode from Flags.
module Emf
  module Conformance
    module EmfPlusProperties
      Records = Emf::EmfPlus::Records
      Support = EmfPlusSupport

      # record class => [decoded reader, allowed values, enumeration name] (MS-EMFPLUS 2.1.1 enumerations).
      ENUMS = {
        Records::SetAntiAliasMode => [:smoothing_mode, (0..5), "SmoothingMode"],
        Records::SetTextRenderingHint => [:text_rendering_hint, (0..5), "TextRenderingHint"],
        Records::SetInterpolationMode => [:interpolation_mode, (0..7), "InterpolationMode"],
        Records::SetPixelOffsetMode => [:pixel_offset_mode, (0..4), "PixelOffsetMode"],
        Records::SetCompositingMode => [:compositing_mode, (0..1), "CompositingMode"],
        Records::SetCompositingQuality => [:compositing_quality, (1..5), "CompositingQuality"],
        Records::SetClipRect => [:combine_mode, (0..5), "CombineMode"],
        Records::SetClipPath => [:combine_mode, (0..5), "CombineMode"],
        Records::SetClipRegion => [:combine_mode, (0..5), "CombineMode"]
      }.freeze
      UNIT_TYPE = (0..6)
      UNIT_WORLD_OR_DISPLAY = (0..1)
      CONTRAST = (1000..2200)

      module_function

      def enum_domain(located)
        record = located.record
        reader, domain, name = ENUMS.find { |klass, _| record.is_a?(klass) }&.last
        return unless reader

        value = record.public_send(reader)
        return if domain.cover?(value)

        "#{Support.type_name(record)} #{name} value #{value} is outside #{domain.first}..#{domain.last}"
      end

      def text_contrast(located)
        record = located.record
        return unless record.is_a?(Records::SetTextContrast) && !CONTRAST.cover?(record.text_contrast)

        "EmfPlusSetTextContrast TextContrast #{record.text_contrast} is outside 1000..2200"
      end

      def page_unit_value(record)
        case record
        when Records::SetPageTransform, Records::BeginContainer then record.page_unit
        end
      end

      def page_unit_domain(located)
        unit = page_unit_value(located.record)
        return if unit.nil? || UNIT_TYPE.cover?(unit)

        "#{Support.type_name(located.record)} PageUnit #{unit} is not a UnitType value (0..6)"
      end

      def page_unit_discouraged(located)
        unit = page_unit_value(located.record)
        return unless unit && UNIT_WORLD_OR_DISPLAY.cover?(unit)

        "#{Support.type_name(located.record)} PageUnit #{unit} (UnitType#{unit.zero? ? 'World' : 'Display'}) SHOULD NOT be used"
      end
    end

    EmfPlusSupport.per_record(id: "emfplus.property.enum", citation: "MS-EMFPLUS 2.3.6", kind: :property_enum,
                              tolerant_reason: "a real producer writes CompositingQuality 0 (spec/fixtures/emf/test-000.emf)") do |located|
      EmfPlusProperties.enum_domain(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.property.text_contrast", citation: "MS-EMFPLUS 2.3.6.7", kind: :text_contrast) do |located|
      EmfPlusProperties.text_contrast(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.transform.page_unit", citation: "MS-EMFPLUS 2.3.9", kind: :page_unit) do |located|
      EmfPlusProperties.page_unit_domain(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.transform.page_unit_discouraged", citation: "MS-EMFPLUS 2.3.9",
                              kind: :page_unit_discouraged, severity: :warning) do |located|
      EmfPlusProperties.page_unit_discouraged(located)
    end
  end
end
