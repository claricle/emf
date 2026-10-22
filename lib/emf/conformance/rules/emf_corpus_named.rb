# frozen_string_literal: true

# Rules that name two corruptions in spec/fixtures/emf-corrupted whose records the parser keeps as
# Raw (a Size below the record's fixed layout), which the decoded-wire rules of the state and text
# families skip:
#   bad_corrupted_2014-12-13-132605.emf   EMR_SETICMMODE with Size 8 (stated 12)
#   bad_corrupted_2017-05-12-074000.emf   EMR_EXTTEXTOUTW with Size 12 (EmrText needs 24 bytes)
module Emf
  module Conformance
    module CorpusNamedRules
      EMF = %i[emf emf_plus].freeze
      RECOVERED = "the parser recovered and kept the bytes as a raw record, and readers advance by the declared Size"
      # Type and Size (8) + Bounds (16) + iGraphicsMode, exScale, eyScale (12).
      EXT_TEXT_AT = 36
      # EmrText without the optional Rectangle: Reference, Chars, offString, Options, offDx.
      EMR_TEXT_MIN = 24
      EXT_TEXT_TYPES = { 83 => "EMR_EXTTEXTOUTA", 84 => "EMR_EXTTEXTOUTW" }.freeze

      module_function

      def raw?(record) = !record.wire.is_a?(Emf::Emr::Binary::Record)

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      # type => [required Size, exact?]. A decodable state record is checked by emf.state.fixed_size and
      # emf.state.layout_size; only a Raw one escapes them.
      def size_table
        table = StateRules::STATED_SIZE.transform_values { |size| [size, true] }
        StateRules::LAYOUT_SIZE.each { |type, size| table[type] ||= [size, false] }
        table
      end

      def raw_fixed_size(context)
        table = size_table
        found = []
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          required, exact = table[type]
          next unless required && raw?(record)

          size = context.record_size(record)
          next if exact ? size == required : size >= required
          next if StateRules::SHORT_BY_OPAQUE.include?(type) # a short one is emf.opaque.fixed_size, any record

          found << at(record, index,
                      "#{RecordTypes.name(type)} (#{StateRules::SECTION.fetch(type)}) Size is #{size}, " \
                      "#{exact ? 'the record section states' : 'its fixed fields occupy'} #{required}; kept as a raw record")
        end
        found
      end

      def exttextout_fixed_part(context)
        minimum = EXT_TEXT_AT + EMR_TEXT_MIN
        found = []
        context.records.each_with_index do |record, index|
          name = EXT_TEXT_TYPES[context.record_type(record)]
          next unless name && raw?(record)

          size = context.record_size(record)
          next if size >= minimum

          found << at(record, index, "#{name} Size #{size} is smaller than its #{minimum}-byte fixed part " \
                                     "(header, Bounds, iGraphicsMode, scales and an EmrText without Rectangle)")
        end
        found
      end
    end

    registry = Registry.loading
    registry.register(id: "emf.record.fixed_size_raw", formats: CorpusNamedRules::EMF, citation: "MS-EMF 2.3.11",
                      kind: :fixed_size_raw, tolerant_reason: CorpusNamedRules::RECOVERED) do |context|
      CorpusNamedRules.raw_fixed_size(context)
    end
    registry.register(id: "emf.record.exttextout_fixed_part", formats: CorpusNamedRules::EMF, citation: "MS-EMF 2.2.5",
                      kind: :exttextout_fixed_part, tolerant_reason: CorpusNamedRules::RECOVERED) do |context|
      CorpusNamedRules.exttextout_fixed_part(context)
    end
  end
end
