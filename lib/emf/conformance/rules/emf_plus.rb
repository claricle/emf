# frozen_string_literal: true

# EMF+ adapter: maps the existing Emf::EmfPlus::Stream::Conformance diagnostics
# (and the stream's other framing errors) onto lens rules. Offsets are the file
# offset of the EMR_COMMENT that carries the EMF+ record.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module EmfPlusRules
      KINDS = {
        reserved_type: ["emfplus.record.reserved_type", "MS-EMFPLUS 2.1.1.1"],
        stroke_fill_path: ["emfplus.record.stroke_fill_path", "MS-EMFPLUS 2.1.1.1"],
        unknown_type: ["emfplus.record.unknown_type", "MS-EMFPLUS 2.1.1.1"],
        header_not_after_emf_header: ["emfplus.header.placement", "MS-EMFPLUS 2.3.3.3"]
      }.freeze
      TOLERATED = "the records stay readable as unknown records with their bytes intact; corpus files carry them"
      STREAM_ID = "emfplus.stream.framing"

      module_function

      def findings(context, id)
        stream = context.metafile.emf_plus_stream
        return [] unless stream

        undecodable = id == STREAM_ID ? undecodable_types(context) : []
        stream.errors.filter_map do |error|
          next unless rule_id(error) == id
          next if owned_elsewhere?(error, undecodable)

          finding(context, error)
        end
      end

      # A record body that does not decode is emfplus.record.body_bounds, and a missing or non-adjacent effect is
      # emfplus.object.effect_missing; both are located at the record, so the stream-wide copy is dropped.
      def owned_elsewhere?(error, undecodable)
        case error
        when Emf::EmfPlus::Links::LinkError then %i[missing_effect non_adjacent_effect].include?(error.reason)
        when Emf::ParseError then undecodable.include?(error.record_code) && error.message.match?(/\Amalformed \w+ body at offset/)
        else false
        end
      end

      def undecodable_types(context)
        EmfPlusSupport.records(context).filter_map do |located|
          located.record.type unless EmfPlusSupport.typed?(located.record) || !Emf::EmfPlus::Records.registry.key?(located.record.type)
        end
      end

      def rule_id(error)
        error.is_a?(Emf::EmfPlus::Stream::Conformance::Diagnostic) ? KINDS.fetch(error.kind).first : STREAM_ID
      end

      def finding(context, error)
        return { message: error.message, offset: nil } unless
          error.is_a?(Emf::EmfPlus::Stream::Conformance::Diagnostic)

        record = context.records[error.comment_index]
        { message: error.message, offset: record&.offset, record_index: error.comment_index + 1, record_type: error.record_type }
      end
    end

    registry = Registry.loading
    EmfPlusRules::KINDS.each do |kind, (id, citation)|
      registry.register(id: id, formats: [:emf_plus], citation: citation, kind: kind,
                        tolerant_reason: EmfPlusRules::TOLERATED) { |context| EmfPlusRules.findings(context, id) }
    end
    registry.register(id: EmfPlusRules::STREAM_ID, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3",
                      kind: :stream_framing,
                      tolerant_reason: "the stream keeps unframed bytes verbatim, so nothing is dropped") do |context|
      EmfPlusRules.findings(context, EmfPlusRules::STREAM_ID)
    end
  end
end
