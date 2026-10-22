# frozen_string_literal: true

return if defined?(Emf::Conformance::EmfPlusSupport)

# Shared helper for the emf_plus_*.rb rule files (no rules of its own). It walks
# the public EMF+ stream and locates each record in the file the way
# emf_plus.rb does: by the file offset of the EMR_COMMENT that carries it, taken from
# the handle's comment_offset (nil on a rebuilt stream, then the comment record's own offset).
module Emf
  module Conformance
    module EmfPlusSupport
      Located = Struct.new(:record, :handle, :comment_index, :comment, keyword_init: true)

      module_function

      # Every EMF+ record of the metafile, in stream order.
      def records(context)
        stream = context.metafile.emf_plus_stream
        return [] unless stream

        stream.each_record.map do |handle|
          index = stream.segments.fetch(handle.segment_index).record_index
          Located.new(record: handle.record, handle: handle, comment_index: index, comment: context.records[index])
        end
      end

      def finding(located, message)
        { message: "#{message} (EMF+ record #{format('0x%04X', located.record.type)} at offset #{located.handle.offset} " \
                   "of EMR_COMMENT_EMFPLUS record #{located.comment_index + 1})",
          offset: located.handle.comment_offset || located.comment&.offset, record_index: located.comment_index + 1,
          record_type: located.record.type }
      end

      # A decoded record (not Records::Unknown).
      def typed?(record) = record.is_a?(Emf::EmfPlus::Records::Base)

      def size_of(record) = typed?(record) ? record.size : record.frame.size

      def data_size_of(record) = typed?(record) ? record.data_size : record.frame.data_size

      def type_name(record)
        klass = Emf::EmfPlus::Records.registry[record.type]
        klass ? klass.name.split("::").last : format("0x%04X", record.type)
      end

      # Registers a rule whose check runs per EMF+ record. The block gets the
      # Located record and returns nil, a message, or an Array of messages.
      def per_record(id:, citation:, kind:, severity: :error, tolerant_reason: nil, &check)
        Registry.loading.register(id: id, formats: [:emf_plus], citation: citation, kind: kind, severity: severity,
                                  tolerant_reason: tolerant_reason) do |context|
          records(context).flat_map { |located| Array(yield(located)).map { |message| finding(located, message) } }
        end
      end
    end
  end
end
