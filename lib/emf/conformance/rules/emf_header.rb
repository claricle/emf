# frozen_string_literal: true

# EMR_HEADER / Header object rules (MS-EMF 2.2.9, 2.3.4.2).
module Emf
  module Conformance
    module HeaderRules
      EMF = %i[emf emf_plus].freeze
      SIGNATURE = 0x464D4520
      FIXED_HEADER_SIZE = 88 # EmfMetafileHeader fixed part (2.3.4.2)
      CREATE_OBJECT_TYPES = [38, 39, 49, 82, 93, 94, 95, 99, 122].freeze
      DRIFT = "the numeric header fields are advisory for renderers; every corpus file with a drifted value still renders"

      module_function

      def finding(message) = { message: message, offset: 0, record_index: 0, record_type: RecordTypes::HEADER }

      def signature(context)
        sig = context.header.signature.to_i
        return [] if sig == SIGNATURE

        [finding(format("RecordSignature is 0x%08X, MUST be ENHMETA_SIGNATURE 0x464D4520", sig))]
      end

      def size_bounds(context)
        size = context.header.n_size.to_i
        problems = []
        problems << "header Size #{size} is below the #{FIXED_HEADER_SIZE}-byte fixed part" if size < FIXED_HEADER_SIZE
        problems << "header Size #{size} is not a multiple of 4" unless (size % 4).zero?
        problems.map { |message| finding(message) }
      end

      def bytes_mismatch(context)
        actual = context.byte_length
        declared = context.header.n_bytes.to_i
        return [] if actual.nil? || declared == actual

        [finding("header Bytes is #{declared} but the metafile is #{actual} bytes")]
      end

      def records_mismatch(context)
        declared = context.header.n_records.to_i
        return [] if declared == context.record_count

        [finding("header Records is #{declared} but the metafile holds #{context.record_count} records")]
      end

      def handle_count(context)
        handles = context.header.n_handles.to_i
        context.records.each_with_index.filter_map do |record, index|
          type = context.record_type(record)
          next unless CREATE_OBJECT_TYPES.include?(type)

          handle = record.to_binary_s.unpack1("V", offset: 8)
          next if handle.nil? || handle < handles

          { message: "object handle index #{handle} created at record #{index + 1} is not below header Handles (#{handles})",
            offset: record.offset, record_index: index + 1, record_type: type }
        end
      end

      def description_bounds(context)
        header = context.header
        chars = header.n_description.to_i
        return [] if chars.zero? && header.off_description.to_i.zero?

        offset = header.off_description.to_i
        problems = []
        problems << "description offset #{offset} is inside the #{FIXED_HEADER_SIZE}-byte fixed part" if offset < FIXED_HEADER_SIZE
        if offset + (2 * chars) > header.n_size.to_i
          problems << "description (#{chars} UTF-16 chars at offset #{offset}) ends past header Size #{header.n_size}"
        end
        problems.map { |message| finding(message) }
      end

      # HeaderExtension1 (and with it the pixel format fields) exists only when
      # the variable-length data starts at byte 100 or later (MS-EMF 2.3.4.2,
      # HeaderSize rule); a description at byte 88 means the original 88-byte header.
      def extension1?(header)
        return header.n_size.to_i >= 100 if header.n_description.to_i.zero?

        header.off_description.to_i >= 100
      end

      def pixel_format_bounds(context)
        header = context.header
        return [] unless extension1?(header)

        size = header.cb_pixel_format.to_i
        offset = header.off_pixel_format.to_i
        return [] if size.zero? && offset.zero?
        return [] if offset >= FIXED_HEADER_SIZE && offset + size <= header.n_size.to_i

        [finding("pixel format (#{size} bytes at offset #{offset}) lies outside the header record (Size #{header.n_size})")]
      end
    end

    registry = Registry.loading
    {
      "emf.header.signature" => [:signature, "MS-EMF 2.2.9", :signature, nil],
      "emf.header.size_bounds" => [:size_bounds, "MS-EMF 2.3.4.2", :header_size, nil],
      "emf.header.bytes" => [:bytes_mismatch, "MS-EMF 2.2.9", :bytes_mismatch, HeaderRules::DRIFT],
      "emf.header.records" => [:records_mismatch, "MS-EMF 2.2.9", :records_mismatch, HeaderRules::DRIFT],
      "emf.header.handles" => [:handle_count, "MS-EMF 2.2.9", :handle_count, HeaderRules::DRIFT],
      "emf.header.description_bounds" => [:description_bounds, "MS-EMF 2.2.9", :description_bounds, HeaderRules::DRIFT],
      "emf.header.pixel_format_bounds" => [:pixel_format_bounds, "MS-EMF 2.2.10", :pixel_format_bounds, HeaderRules::DRIFT]
    }.each do |id, (method, citation, kind, reason)|
      registry.register(id: id, formats: HeaderRules::EMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        HeaderRules.public_send(method, context)
      end
    end
  end
end
