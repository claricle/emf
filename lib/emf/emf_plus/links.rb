# frozen_string_literal: true

module Emf
  module EmfPlus
    # Ordering and linking rules that span EMF+ records and the EMF records
    # around them. Works on framed records (Parser.from_metafile), never decodes
    # or alters bytes, and reports problems instead of raising.
    module Links
      autoload :GetDcSpan, "emf/emf_plus/links/get_dc_span"
      autoload :EffectLink, "emf/emf_plus/links/effect_link"
      autoload :LinkError, "emf/emf_plus/links/link_error"

      GET_DC = 0x4004
      SERIALIZABLE_OBJECT = 0x4038
      DRAW_IMAGE_POINTS = 0x401B
      EFFECT_FLAG = 0x2000

      module_function

      # MS-EMFPLUS 2.3.3.2: EMF records are processed after an EmfPlusGetDC
      # until the next EMF+ record. A GetDC that is not last in its comment is
      # followed by an EMF+ record at once, so its span is empty; otherwise the
      # span runs to the next comment carrying EMF+ records (or the end).
      def get_dc_spans(metafile, frames)
        frames.each_with_index.filter_map do |frame, index|
          next unless frame.type == GET_DC

          GetDcSpan.new(comment_index: frame.comment_index, offset: frame.offset,
                        emr_range: emr_range_after(frames, index, metafile.records.size))
        end
      end

      # MS-EMFPLUS 2.3.4.9 says an E-flag DrawImagePoints needs an "earlier"
      # SerializableObject without saying how far back. Only the immediately
      # preceding EMF+ record (across comments) is linked; anything else is
      # reported. Returns [links, errors].
      def effect_links(frames)
        links = []
        errors = []
        frames.each_with_index do |frame, index|
          next unless effect_draw?(frame)

          effect = frames[index - 1] if index.positive? && frames[index - 1].type == SERIALIZABLE_OBJECT
          effect ? links << EffectLink.new(draw: frame, effect: effect) : errors << effect_error(frames, index)
        end
        [links.freeze, errors.freeze]
      end

      def emr_range_after(frames, index, record_count)
        frame = frames[index]
        following = frames[index + 1]
        first = frame.comment_index + 1
        return first...first if following&.comment_index == frame.comment_index

        first...(following ? following.comment_index : record_count)
      end

      def effect_draw?(frame)
        frame.type == DRAW_IMAGE_POINTS && frame.flags.anybits?(EFFECT_FLAG)
      end

      def effect_error(frames, index)
        frame = frames[index]
        earlier = frames[0...index].any? { |f| f.type == SERIALIZABLE_OBJECT }
        reason = earlier ? :non_adjacent_effect : :missing_effect
        message = if earlier
                    "E-flag DrawImagePoints is not immediately preceded by a SerializableObject"
                  else
                    "E-flag DrawImagePoints has no SerializableObject"
                  end
        LinkError.new(reason: reason, comment_index: frame.comment_index, offset: frame.offset, message: message)
      end

      private_class_method :emr_range_after, :effect_draw?, :effect_error
    end
  end
end
