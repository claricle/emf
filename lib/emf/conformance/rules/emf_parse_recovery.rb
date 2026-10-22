# frozen_string_literal: true

# Parse-recovery errors (Metafile#errors) and unparseable input become
# diagnostics. The record count and offsets come from the ParseError itself.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module ParseRecoveryRules
      EMF = %i[emf emf_plus].freeze
      RECOVERED = "the parser recovered and kept the bytes (as a raw record or trailing data), so the file still opens"

      # Recovered ParseErrors (Metafile#errors) carry no #evidence on either backend (measured 2026-10-22:
      # Emf::ParseEvidence is attached only to the FormatError/ParseError raised for an input that yields no
      # metafile, and none of its check symbols describes a recovered record). Their rule id is therefore
      # chosen from the message. When recovered errors start carrying evidence, classify from
      # error.evidence.check first and keep this table as the fallback for errors without evidence;
      # spec/emf/conformance/parse_recovery_spec.rb fails the day that happens.
      #
      # message pattern => [rule id, kind]
      CLASSES = [
        [/header/, "emf.record.truncated_header", :truncated_header],
        [/nSize \d+ < 8/, "emf.record.size_minimum", :size_minimum],
        [/truncated record/, "emf.record.size_bounds", :size_bounds],
        [/declares more entries than nSize allows/, "emf.record.array_exceeds_size", :array_exceeds_size]
      ].freeze
      OTHER = ["emf.record.undecodable", :undecodable].freeze

      module_function

      def classify(error) = CLASSES.find { |pattern, *| pattern.match?(error.message) }&.drop(1) || OTHER

      # Text rules that name the same too-large count or too-small record the parser recovered as Raw; where one
      # fires on the record, the recovery diagnostic would only repeat it.
      TEXT_OWNERS = %w[emf.exttextout.string_bounds emf.exttextout.dx_bounds].freeze

      def findings(context, id)
        owned = id == "emf.record.array_exceeds_size" ? text_owned_offsets(context) : []
        context.metafile.errors.filter_map do |error|
          next unless classify(error).first == id
          next if owned.include?(error.offset)

          { message: error.message, offset: error.offset, record_type: error.record_code }
        end
      end

      def text_owned_offsets(context)
        (TEXT_OWNERS.flat_map { |owner| TextRules.findings(context, owner) } + CorpusNamedRules.exttextout_fixed_part(context))
          .map { |finding| finding[:offset] }
      end

      def unparseable(context)
        failure = context.parse_failure
        return [] if WmfRejectionRules.reason_for(failure) # a named wmf.reject.rNNNN finding already explains it

        [{ message: "input could not be parsed: #{failure.message}", offset: 0 }]
      end
    end

    registry = Registry.loading
    citations = { "emf.record.truncated_header" => "MS-EMF 2.3", "emf.record.size_minimum" => "MS-EMF 2.3",
                  "emf.record.size_bounds" => "MS-EMF 2.3", "emf.record.array_exceeds_size" => "MS-EMF 2.3",
                  "emf.record.undecodable" => "MS-EMF 2.3" }
    (ParseRecoveryRules::CLASSES.map { |_, id, kind| [id, kind] } << ParseRecoveryRules::OTHER).each do |id, kind|
      registry.register(id: id, formats: ParseRecoveryRules::EMF, citation: citations.fetch(id), kind: kind,
                        tolerant_reason: ParseRecoveryRules::RECOVERED) do |context|
        ParseRecoveryRules.findings(context, id)
      end
    end

    registry.register(id: "emf.parse.unparseable", formats: [:unparseable], citation: "MS-EMF 2.3.4.2",
                      kind: :unparseable) { |context| ParseRecoveryRules.unparseable(context) }
  end
end
