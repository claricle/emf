# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

require_relative "emf_plus_common"

# Per-field enumeration and range rules for the decoded EMF+ graphics objects
# (MS-EMFPLUS 2.2.1). CHECKS is a table of object type => check lambda; each
# lambda gets the decoded object and returns the problems it finds. Only a
# clause that says a value "MUST" be, or "is defined in", an enumeration is an
# error here; the bounds of the payload are emfplus.object.payload's.
module Emf
  module Conformance
    module EmfPlusFields
      Objects = Emf::EmfPlus::Objects
      Support = EmfPlusSupport

      # Enumerations, MS-EMFPLUS 2.1.1. LineCapType lists AnchorMask (0xF0) among its values, and a real producer writes it
      # as an EndCap (LibreOffice emfio TestEmfPlusDrawLineWithCaps).
      BRUSH_TYPE = (0..4)
      HATCH_STYLE = (0..0x34)
      WRAP_MODE = (0..4)
      UNIT_TYPE = (0..6)
      LINE_CAP = [0, 1, 2, 3, 0x10, 0x11, 0x12, 0x13, 0x14, 0xF0, 0xFF].freeze
      LINE_JOIN = (0..3)
      LINE_STYLE = (0..5)
      DASHED_LINE_CAP = [0, 2, 3].freeze # DashedLineCapType has no value 1
      PEN_ALIGNMENT = (0..4)
      CUSTOM_LINE_CAP_TYPE = (0..1)
      # Flags, MS-EMFPLUS 2.1.2: every defined bit.
      BRUSH_DATA_FLAGS = 0x1DF # BrushData 0x01..0x10, 0x40, 0x80, 0x100 (0x20 is undefined)
      PEN_DATA_FLAGS = 0x1FFF
      CUSTOM_LINE_CAP_DATA_FLAGS = 0x3

      module_function

      def hex(value) = format("0x%X", value)

      def in_domain(label, value, domain, name)
        return if value.nil?

        ok = domain.is_a?(Array) ? domain.include?(value) : domain.cover?(value)
        return if ok

        shown = domain.is_a?(Array) ? domain.map { |v| hex(v) }.join(", ") : "#{hex(domain.first)}..#{hex(domain.last)}"
        "#{label} #{value} is not a #{name} value (#{shown})"
      end

      def flags_within(label, value, mask, name)
        return if value.nil? || value.nobits?(~mask)

        "#{label} #{hex(value)} sets bits outside the defined #{name} flags (#{hex(mask)})"
      end

      def zero_point(label, point)
        return if point.nil? || (point.x.to_f.zero? && point.y.to_f.zero?)

        "#{label} is {#{point.x}, #{point.y}}, MUST be {0.0, 0.0}"
      end

      # --- Brush, Pen, CustomLineCap ------------------------------------------

      def brush(object)
        type = object.brush_type
        problems = [in_domain("EmfPlusBrush Type", type, BRUSH_TYPE, "BrushType")]
        data = object.data
        case type
        when Objects::Brush::HATCH
          problems << in_domain("EmfPlusHatchBrushData HatchStyle", data.hatch_style, HATCH_STYLE, "HatchStyle")
        when Objects::Brush::TEXTURE, Objects::Brush::PATH_GRADIENT, Objects::Brush::LINEAR_GRADIENT
          problems << flags_within("BrushDataFlags", data.brush_data_flags, BRUSH_DATA_FLAGS, "BrushData")
          problems << in_domain("WrapMode", data.wrap_mode, WRAP_MODE, "WrapMode")
        end
        problems
      end

      def pen(object)
        flags = object.pen_data_flags
        [("EmfPlusPen Type is #{object.pen_type}, MUST be 0" unless object.pen_type.zero?),
         flags_within("PenDataFlags", flags, PEN_DATA_FLAGS, "PenData"),
         in_domain("PenUnit", object.pen_unit, UNIT_TYPE, "UnitType"),
         in_domain("StartCap", object.start_cap, LINE_CAP, "LineCapType"),
         in_domain("EndCap", object.end_cap, LINE_CAP, "LineCapType"),
         in_domain("PenAlignment", object.pen_alignment, PEN_ALIGNMENT, "PenAlignment"),
         *[object.custom_start_cap, object.custom_end_cap].compact.flat_map { |cap| custom_line_cap(cap) }]
      end

      # Join, LineStyle and DashedLineCapType: corrupt-by-design LibreOffice fuzz regressions write garbage here and
      # are expected to stay readable, so this group alone is waived in tolerant (see PEN_LINE_WAIVER).
      def pen_line(object)
        [in_domain("Join", object.join, LINE_JOIN, "LineJoinType"),
         in_domain("LineStyle", object.line_style, LINE_STYLE, "LineStyle"),
         in_domain("DashedLineCapType", object.dashed_line_cap, DASHED_LINE_CAP, "DashedLineCapType")]
      end

      def custom_line_cap(object)
        data = object.data
        problems = [in_domain("EmfPlusCustomLineCap Type", object.cap_type, CUSTOM_LINE_CAP_TYPE, "CustomLineCapDataType")]
        case object.cap_type
        when Objects::CustomLineCap::DEFAULT
          problems.concat(custom_line_cap_default(data))
        when Objects::CustomLineCap::ADJUSTABLE_ARROW
          problems.concat(custom_line_cap_arrow(data))
        end
        problems
      end

      def custom_line_cap_default(data)
        [flags_within("CustomLineCapDataFlags", data.custom_line_cap_data_flags, CUSTOM_LINE_CAP_DATA_FLAGS, "CustomLineCapData"),
         in_domain("BaseCap", data.base_cap, LINE_CAP, "LineCapType"),
         in_domain("StrokeStartCap", data.stroke_start_cap, LINE_CAP, "LineCapType"),
         in_domain("StrokeEndCap", data.stroke_end_cap, LINE_CAP, "LineCapType"),
         in_domain("StrokeJoin", data.stroke_join, LINE_JOIN, "LineJoinType"),
         zero_point("FillHotSpot", data.fill_hot_spot), zero_point("StrokeHotSpot", data.stroke_hot_spot)]
      end

      def custom_line_cap_arrow(data)
        [in_domain("LineStartCap", data.line_start_cap, LINE_CAP, "LineCapType"),
         in_domain("LineEndCap", data.line_end_cap, LINE_CAP, "LineCapType"),
         in_domain("LineJoin", data.line_join, LINE_JOIN, "LineJoinType"),
         zero_point("FillHotSpot", data.fill_hot_spot), zero_point("LineHotSpot", data.line_hot_spot)]
      end

      # Object type => check. Each group below owns its own entries.
      CHECKS = {
        # Brush, Pen, CustomLineCap
        Objects::BRUSH => method(:brush),
        Objects::PEN => method(:pen),
        Objects::CUSTOM_LINE_CAP => method(:custom_line_cap),
        # Path, Region, Font, StringFormat, ImageAttributes
        **[Objects::PATH, Objects::REGION, Objects::FONT, Objects::STRING_FORMAT, Objects::IMAGE_ATTRIBUTES]
               .to_h { |type| [type, ->(object) { EmfPlusFieldsB.findings_for(object) }] }
      }.freeze

      # Same shape as CHECKS, for the fields a real corpus file violates.
      WAIVED_CHECKS = {
        # Brush, Pen, CustomLineCap
        Objects::PEN => method(:pen_line)
      }.freeze

      PEN_LINE_WAIVER = "fuzz-regression files LibreOffice ships as readable inputs write out-of-domain pen Join / " \
                        "DashedLineCapType values (vcl graphicfilter emf_fail_crash-2, emf_pass_crash-1, emf_fail_hang-1, " \
                        "emf_fail_hang-2); importers ignore them and keep drawing"

      def object_fields(stream, located, table = CHECKS)
        logical = EmfPlusPayloads.completed_object(stream, located)
        check = logical && table[logical.object_type]
        return unless check

        label = "EmfPlusObject (object type #{logical.object_type}, ID #{logical.emf_object_id})"
        check.call(logical.body).compact.map { |problem| "#{label} #{problem}" }
      rescue Emf::ParseError
        nil # reported by emfplus.object.payload
      end
    end

    Registry.loading.register(id: "emfplus.object.fields", formats: [:emf_plus], citation: "MS-EMFPLUS 2.2.1",
                              kind: :object_fields, tolerant_reason: nil) do |context|
      EmfPlusPayloads.per_object(context) { |stream, located| EmfPlusFields.object_fields(stream, located) }
    end

    Registry.loading.register(id: "emfplus.object.pen_line_fields", formats: [:emf_plus], citation: "MS-EMFPLUS 2.2.2.34",
                              kind: :object_pen_line, tolerant_reason: EmfPlusFields::PEN_LINE_WAIVER) do |context|
      EmfPlusPayloads.per_object(context) do |stream, located|
        EmfPlusFields.object_fields(stream, located, EmfPlusFields::WAIVED_CHECKS)
      end
    end
  end
end
