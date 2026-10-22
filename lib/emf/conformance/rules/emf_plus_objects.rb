# frozen_string_literal: true

return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

require_relative "emf_plus_common"

# Turns the public object-resolution results (Stream#resolve -> ObjectTable::Resolution)
# into diagnostics at the referring record. The resolver itself is not copied.
# Object-definition problems (incomplete chains, definition IDs out of range) are
# ObjectTable#errors, which emf_plus.rb already reports as emfplus.stream.framing.
module Emf
  module Conformance
    module EmfPlusObjects
      Support = EmfPlusSupport

      KINDS = {
        empty_slot: ["emfplus.object.empty_slot", "refers to an object slot with no object defined before this record"],
        wrong_type: ["emfplus.object.wrong_type", "refers to a slot holding an object of a different type"],
        object_id_out_of_range: ["emfplus.object.id_range", "has an object ID outside 0..63"]
      }.freeze

      module_function

      def findings(context, kind)
        stream = context.metafile.emf_plus_stream
        return [] unless stream

        Support.records(context).flat_map do |located|
          stream.resolve(located.handle).filter_map do |resolution|
            next unless resolution.diagnostic&.kind == kind

            Support.finding(located, "#{Support.type_name(located.record)} #{resolution.role} reference " \
                                     "#{resolution.raw_id} #{KINDS.fetch(kind).last}")
          end
        end
      end
    end

    # MS-EMFPLUS 2.3.4.9: an E-flag DrawImagePoints needs an Effect specified in an earlier
    # SerializableObject. Stream#effect_for is the public link (the immediately preceding record).
    Registry.loading.register(id: "emfplus.object.effect_missing", formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.4.9",
                              kind: :effect_link, tolerant_reason: nil) do |context|
      stream = context.metafile.emf_plus_stream
      next [] unless stream

      EmfPlusSupport.records(context).filter_map do |located|
        # Type and flags come from the record frame, so an E-flag draw whose body does not decode is still checked.
        record = located.record
        draw = Emf::EmfPlus::Records::DrawImagePoints
        next unless record.type == draw::TYPE && record.flags.anybits?(draw::EFFECT_FLAG)
        next if stream.effect_for(located.handle)

        EmfPlusSupport.finding(located, "DrawImagePoints has the effect flag but no SerializableObject record immediately precedes it")
      end
    end

    EmfPlusObjects::KINDS.each do |kind, (id, _)|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.4", kind: kind,
                                tolerant_reason: nil) { |context| EmfPlusObjects.findings(context, kind) }
    end
  end
end
