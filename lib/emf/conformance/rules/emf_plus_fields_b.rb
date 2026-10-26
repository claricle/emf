# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

# Field-domain checks of the Path, Region, Font, StringFormat and ImageAttributes graphics objects
# (MS-EMFPLUS 2.2.1.3, 2.2.1.5, 2.2.1.6, 2.2.1.8, 2.2.1.9). No rule is registered here: the shared
# "emfplus.object.fields" rule (emf_plus_fields.rb) calls findings_for(object) for each completed object.
# Only MUST-level domains are reported. SHOULD-level text (HotkeyPrefix/StringFormat flag descriptions,
# "Windows never uses UnitTypeDisplay" in Font SizeUnit) is not an error and is not reported.
module Emf
  module Conformance
    module EmfPlusFieldsB
      Objects = Emf::EmfPlus::Objects

      UNIT_TYPE = (0..6) # 2.1.1.32; 2.2.1.3 SizeUnit "is in the UnitType enumeration"
      FONT_STYLE_MASK = 0xF # 2.1.2.4: Bold, Italic, Underline, Strikeout
      PATH_POINT_TYPES = [0x0, 0x1, 0x3].freeze # 2.1.1.22: Start, Line, Bezier
      PATH_POINT_FLAGS_MASK = 0x0B # 2.1.2.6 (high nibble): DashMode 0x1, PathMarker 0x2, CloseSubpath 0x8
      WRAP_MODE = (0..4) # 2.1.1.33
      OBJECT_CLAMP = (0..1) # 2.2.1.5 "MUST be one of": RectClamp, BitmapClamp
      STRING_ALIGNMENT = (0..2) # 2.1.1.28
      DIGIT_SUBSTITUTION = (0..3) # 2.1.1.29
      HOTKEY_PREFIX = (0..2) # 2.1.1.14
      STRING_TRIMMING = (0..5) # 2.1.1.30
      # 2.1.2.8: DirectionRightToLeft, DirectionVertical, NoFitBlackBox, DisplayFormatControl, NoFontFallback,
      # MeasureTrailingSpaces, NoWrap, LineLimit, NoClip, BypassGDI.
      STRING_FORMAT_FLAGS_MASK = 0x1 | 0x2 | 0x4 | 0x20 | 0x400 | 0x800 | 0x1000 | 0x2000 | 0x4000 | 0x80000000

      module_function

      # `object` is a completed logical object (object_type, body) or an already decoded Objects::Typed.
      def findings_for(object)
        typed = object.is_a?(Objects::Typed) ? object : object.body
        case typed
        when Objects::Path then path(typed)
        when Objects::Region then region(typed)
        when Objects::Font then font(typed)
        when Objects::StringFormat then string_format(typed)
        when Objects::ImageAttributes then image_attributes(typed)
        else []
        end
      end

      def domain(label, value, allowed)
        return [] if allowed.cover?(value)

        ["#{label} #{value} is outside #{allowed.first}..#{allowed.last}"]
      end

      def path(path)
        types = path.point_types.flat_map { |entry| entry.respond_to?(:point_type) ? [entry.point_type] : [entry] }
        types.flat_map { |type| path_point_type(type) }.uniq.map { |message| "EmfPlusPath #{message}" }
      end

      def path_point_type(type)
        messages = []
        messages << "PathPointType #{type.type} is not Start (0), Line (1) or Bezier (3)" unless PATH_POINT_TYPES.include?(type.type)
        unless type.flags.nobits?(~PATH_POINT_FLAGS_MASK)
          messages << "PathPointType flags 0x#{format('%X', type.flags)} hold bits other than DashMode, PathMarker and CloseSubpath"
        end
        messages
      end

      # 2.2.1.8: RegionNode is an array of RegionNodeCount + 1 nodes; the tree read from the data must hold exactly that many.
      def region(region)
        expected = region.node_count + 1
        actual = region.root.node_count
        return [] if actual == expected

        ["EmfPlusRegion RegionNodeCount #{region.node_count} declares #{expected} nodes but the node tree holds #{actual}"]
      end

      def font(font)
        messages = domain("EmfPlusFont SizeUnit", font.size_unit, UNIT_TYPE)
        unless font.style_flags.nobits?(~FONT_STYLE_MASK)
          messages << "EmfPlusFont FontStyleFlags 0x#{format('%X',
                                                             font.style_flags & 0xFFFFFFFF)} sets undefined bits"
        end
        messages
      end

      def string_format(object)
        body = object.body
        messages = []
        messages.concat(domain("EmfPlusStringFormat StringAlignment", body.string_alignment, STRING_ALIGNMENT))
        messages.concat(domain("EmfPlusStringFormat LineAlign", body.line_align, STRING_ALIGNMENT))
        messages.concat(domain("EmfPlusStringFormat DigitSubstitution", body.digit_substitution, DIGIT_SUBSTITUTION))
        messages.concat(domain("EmfPlusStringFormat HotkeyPrefix", body.hotkey_prefix, HOTKEY_PREFIX))
        messages.concat(domain("EmfPlusStringFormat Trimming", body.trimming, STRING_TRIMMING))
        unless object.flags.nobits?(~STRING_FORMAT_FLAGS_MASK)
          messages << "EmfPlusStringFormat StringFormatFlags 0x#{format('%X', object.flags)} sets bits that are not StringFormat flags"
        end
        messages
      end

      def image_attributes(attributes)
        domain("EmfPlusImageAttributes WrapMode", attributes.wrap_mode, WRAP_MODE) +
          domain("EmfPlusImageAttributes ObjectClamp", attributes.object_clamp, OBJECT_CLAMP)
      end
    end
  end
end
