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
        validate_sizes(offset, type, size, data_size, remaining, comment_index)
        Frame.new(type: type, flags: flags, size: size, data_size: data_size,
                  data: bytes.byteslice(offset + Frame::HEADER_BYTES, size - Frame::HEADER_BYTES),
                  offset: offset, comment_index: comment_index)
      end

      def validate_sizes(offset, type, size, data_size, remaining, comment_index = nil)
        fail_at(offset, type, "EMF+ record Size #{size} < #{Frame::HEADER_BYTES}") if size < Frame::HEADER_BYTES
        fail_at(offset, type, "EMF+ record Size #{size} is not a multiple of 4") unless (size % 4).zero?
        fail_at(offset, type, "EMF+ record DataSize #{data_size} exceeds Size #{size} - 12") if data_size > size - Frame::HEADER_BYTES
        fail_at(offset, type, truncated_message(size, remaining, comment_index, offset)) if size > remaining
      end

      # MS-EMFPLUS 1.3 and MS-EMF 2.3.3.2: an EMR_COMMENT_EMFPLUS holds whole
      # EMF+ records; only an EmfPlusObject (C flag) continues in a later record.
      # A record that runs past its comment is therefore malformed, not split.
      def truncated_message(size, remaining, comment_index, offset)
        return "truncated EMF+ record (Size #{size}, #{remaining} bytes left)" unless comment_index

        "EMF+ record (Size #{size}) overruns EMR_COMMENT_EMFPLUS record #{comment_index} by " \
          "#{size - remaining} bytes; a record cannot span comments (comment payload offset #{offset})"
      end

      def fail_at(offset, type, message)
        raise ParseError.new(offset: offset, record_code: type, message: "#{message} at offset #{offset}")
      end
    end
  end
end
