# frozen_string_literal: true

module Emf
  module EmfPlus
    # Frames EMF+ records without decoding their bodies. Unknown record types
    # are framed like any other, so nothing is dropped.
    #
    # Malformed framing raises Emf::ParseError. Pass `errors:` (an Array) to
    # instead collect the ParseError and stop framing the stream at that point,
    # the way Emr::Parser treats a corrupt EMR record.
    module Parser
      module_function

      def call(bytes, errors: nil, comment_index: nil)
        bytes = bytes.b
        frames = []
        offset = 0
        while offset < bytes.bytesize
          frame = read_frame(bytes, offset, comment_index)
          frames << frame
          offset += frame.size
        end
        frames
      rescue ParseError => e
        raise unless errors

        errors << e
        frames
      end

      # Frames each EMF+ comment of a parsed Metafile separately, tagging every
      # frame with the index (into metafile.records) of the comment it came
      # from. Concatenating the comment payloads gives Metafile#emf_plus.
      def from_metafile(metafile, errors: nil)
        metafile.records.each_with_index.flat_map do |record, index|
          next [] unless record.wire.is_a?(Emf::Emr::Binary::Records::Comment)

          call(Emf::Emr::Parser.extract_emf_plus(record.wire), errors: errors, comment_index: index)
        end
      end

      def read_frame(bytes, offset, comment_index)
        remaining = bytes.bytesize - offset
        fail_at(offset, nil, "truncated EMF+ record header (#{remaining} bytes left)") if remaining < Frame::HEADER_BYTES

        type, flags, size, data_size = bytes.byteslice(offset, Frame::HEADER_BYTES).unpack("vvVV")
        validate_sizes(offset, type, size, data_size, remaining)
        Frame.new(type: type, flags: flags, size: size, data_size: data_size,
                  data: bytes.byteslice(offset + Frame::HEADER_BYTES, size - Frame::HEADER_BYTES),
                  offset: offset, comment_index: comment_index)
      end

      def validate_sizes(offset, type, size, data_size, remaining)
        fail_at(offset, type, "EMF+ record Size #{size} < #{Frame::HEADER_BYTES}") if size < Frame::HEADER_BYTES
        fail_at(offset, type, "EMF+ record Size #{size} is not a multiple of 4") unless (size % 4).zero?
        fail_at(offset, type, "EMF+ record DataSize #{data_size} exceeds Size #{size} - 12") if data_size > size - Frame::HEADER_BYTES
        fail_at(offset, type, "truncated EMF+ record (Size #{size}, #{remaining} bytes left)") if size > remaining
      end

      def fail_at(offset, type, message)
        raise ParseError.new(offset: offset, record_code: type, message: "#{message} at offset #{offset}")
      end
    end
  end
end
