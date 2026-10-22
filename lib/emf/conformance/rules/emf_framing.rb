# frozen_string_literal: true

# Record framing, EOF and comment rules (MS-EMF 2.1.1, 2.3, 2.3.3, 2.3.4.1).
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module FramingRules
      EMF = %i[emf emf_plus].freeze
      TOLERATED = "records of unassigned type are skipped by size, so the stream stays readable"

      module_function

      def alignment(context)
        context.records.each_with_index.filter_map do |record, index|
          size = context.record_size(record)
          next if (size % 4).zero?

          at(record, index, "record Size #{size} is not a multiple of 4")
        end
      end

      def undefined_type(context)
        context.records.each_with_index.filter_map do |record, index|
          type = context.record_type(record)
          next if RecordTypes.defined?(type)

          at(record, index, format("record type 0x%04X is not in the RecordType enumeration", type))
        end
      end

      def eof_missing(context)
        last = context.records.last
        return [] if last && context.record_type(last) == RecordTypes::EOF_RECORD

        [{ message: "metafile does not end with an EMR_EOF record", offset: last&.offset || context.header.n_size.to_i,
           record_index: context.records.size, record_type: last && context.record_type(last) }]
      end

      def eof_size_last(context)
        last = context.records.last
        return [] unless last && context.record_type(last) == RecordTypes::EOF_RECORD

        bytes = last.to_binary_s
        size = context.record_size(last)
        size_last = bytes.byteslice(-4, 4)&.unpack1("V")
        return [] if size_last == size

        at(last, context.records.size - 1, "EMR_EOF SizeLast is #{size_last.inspect}, MUST equal Size (#{size})")
      end

      def trailing_bytes(context)
        extra = context.metafile.trailing.bytesize
        return [] if extra.zero?

        [{ message: "#{extra} bytes follow the last record", offset: context.byte_length && (context.byte_length - extra),
           record_index: context.records.size }]
      end

      def comment_data_size(context)
        context.records.each_with_index.filter_map do |record, index|
          next unless context.record_type(record) == RecordTypes::COMMENT

          size = context.record_size(record)
          data_size = record.to_binary_s.unpack1("V", offset: 8)
          next if data_size.nil? || data_size <= size - 12

          at(record, index, "comment DataSize #{data_size} exceeds the #{[size - 12, 0].max} bytes the record holds after DataSize")
        end
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end
    end

    registry = Registry.loading
    {
      "emf.record.size_alignment" => [:alignment, "MS-EMF 2.3", :size_alignment,
                                      "readers advance by the declared Size, so a misaligned record still delimits the stream"],
      "emf.record.undefined_type" => [:undefined_type, "MS-EMF 2.1.1", :undefined_type, FramingRules::TOLERATED],
      "emf.eof.missing" => [:eof_missing, "MS-EMF 2.3.4.1", :eof_missing, "truncated files still render the records that survive"],
      "emf.eof.size_last" => [:eof_size_last, "MS-EMF 2.3.4.1", :eof_size_last,
                              "no reader uses SizeLast; some producers write the metafile length there"],
      "emf.eof.trailing_bytes" => [:trailing_bytes, "MS-EMF 2.3.4.1", :trailing_bytes, "bytes after EMR_EOF are ignored by readers"],
      "emf.comment.data_size" => [:comment_data_size, "MS-EMF 2.3.3", :comment_data_size,
                                  "readers clamp DataSize to the record, so the oversized value is never followed"]
    }.each do |id, (method, citation, kind, reason)|
      registry.register(id: id, formats: FramingRules::EMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        FramingRules.public_send(method, context)
      end
    end
  end
end
