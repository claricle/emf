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

      OPTIONAL_REFERENCE = "the referenced object (StringFormatId, ImageAttributesID, a clip Region) is optional or absent and " \
                           "producers write 0xFFFFFFFF, 0 or a never-defined slot for none; importers skip it and keep drawing " \
                           "(corpus: LibreOffice emfio TestDrawStringTransparent, TestDrawImagePointsTypeBitmap, " \
                           "TestDrawStringWithBrush, cppcanvas fdo77229, graphicfilter pass_fdo38580-3)"

      KINDS = {
        empty_slot: ["emfplus.object.empty_slot", "refers to an object slot with no object defined before this record"],
        wrong_type: ["emfplus.object.wrong_type", "refers to a slot holding an object of a different type"],
        object_id_out_of_range: ["emfplus.object.id_range", "has an object ID outside 0..63"]
      }.freeze

      # Optional references (MS-EMFPLUS: StringFormatId, ImageAttributesID; the clip Region of SetClipRegion as
      # written by the corpus producers). Every other role (pen, brush, path, font, image, fill region) is mandatory.
      OPTIONAL_ROLES = %i[string_format image_attributes].freeze

      OPTIONAL_KINDS = {
        empty_slot: ["emfplus.object.optional_empty_slot",
                     "refers to an optional object slot with no object defined before this record"],
        object_id_out_of_range: ["emfplus.object.optional_id_range",
                                 "has an optional object reference with an ID outside 0..63"]
      }.freeze

      module_function

      # A SetClipRegion naming a never-defined slot is a measured producer pattern (LibreOffice fdo38580-3); an
      # out-of-range id is not, and MS-EMFPLUS 2.3.1.5 limits the Region ObjectID to 0..63, so it stays mandatory.
      def optional?(located, resolution)
        return true if OPTIONAL_ROLES.include?(resolution.role)

        located.record.is_a?(Emf::EmfPlus::Records::SetClipRegion) && resolution.diagnostic&.kind == :empty_slot
      end

      def findings(context, kind, optional: false)
        stream = context.metafile.emf_plus_stream
        return [] unless stream

        Support.records(context).flat_map do |located|
          stream.resolve(located.handle).filter_map do |resolution|
            next unless resolution.diagnostic&.kind == kind
            next unless kind == :wrong_type || optional?(located, resolution) == optional

            Support.finding(located, "#{Support.type_name(located.record)} #{resolution.role} reference " \
                                     "#{resolution.raw_id} #{(optional ? OPTIONAL_KINDS : KINDS).fetch(kind).last}")
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

      located_records = EmfPlusSupport.records(context)
      located_records.each_with_index.filter_map do |located, index|
        # Type and flags come from the record frame, so an E-flag draw whose body does not decode is still checked.
        record = located.record
        draw = Emf::EmfPlus::Records::DrawImagePoints
        next unless record.type == draw::TYPE && record.flags.anybits?(draw::EFFECT_FLAG)
        next if stream.effect_for(located.handle)
        # The clause says "an earlier" SerializableObject, not the immediately preceding one.
        next if located_records.first(index).any? { |earlier| earlier.record.type == Emf::EmfPlus::Records::SerializableObject::TYPE }

        EmfPlusSupport.finding(located, "DrawImagePoints has the effect flag but no SerializableObject record precedes it")
      end
    end

    EmfPlusObjects::KINDS.each do |kind, (id, _)|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.4", kind: kind,
                                tolerant_reason: nil) { |context| EmfPlusObjects.findings(context, kind) }
    end

    EmfPlusObjects::OPTIONAL_KINDS.each do |kind, (id, _)|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: "MS-EMFPLUS 2.3.4", kind: :"optional_#{kind}",
                                tolerant_reason: EmfPlusObjects::OPTIONAL_REFERENCE) do |context|
        EmfPlusObjects.findings(context, kind, optional: true)
      end
    end
  end
end
