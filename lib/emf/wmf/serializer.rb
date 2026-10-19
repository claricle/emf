# frozen_string_literal: true

module Emf
  module Wmf
    module Serializer
      module_function

      def call(metafile)
        raise SerializeError, "expected a WMF metafile" unless metafile.format == :wmf && metafile.header.is_a?(Model::Wmf::Header)
        raise SerializeError, "WMF record limit exceeded" if metafile.records.length > Binary::MAX_RECORDS

        validate_eof(metafile.records)
        records = metafile.records.map { |record| serialize_record(record) }
        size = 9 + records.sum { |bytes| bytes.bytesize / 2 }
        raise SerializeError, "WMF input too large" if (size * 2) + metafile.trailing.bytesize > Binary::MAX_INPUT_BYTES

        header = serialize_header(metafile.header, size, records.map { |bytes| bytes.bytesize / 2 }.max)
        placeable = serialize_placeable(metafile.header)
        bytes = placeable + header + records.join + metafile.trailing
        raise SerializeError, "WMF input too large" if bytes.bytesize > Binary::MAX_INPUT_BYTES

        bytes
      end

      def validate_eof(records)
        return if records.last.is_a?(Model::Wmf::Records::Eof) && records.one?(Model::Wmf::Records::Eof)

        raise SerializeError, "WMF requires one final EOF record"
      end

      def serialize_header(header, size, max_record)
        raise SerializeError, "invalid WMF Type" unless [1, 2].include?(header.type)
        raise SerializeError, "invalid WMF Version" unless [0x100, 0x300].include?(header.version)

        [header.type, 9, header.version, size, Binary.uint16(header.number_of_objects, "NumberOfObjects"),
         max_record, Binary.uint16(header.number_of_members, "NumberOfMembers")].pack("v3VvVv")
      end

      def serialize_placeable(header)
        placeable = header.placeable
        return "".b unless placeable
        raise SerializeError, "WMF on-disk placeable handle must be zero" if header.type == 2 && !placeable.handle.zero?

        bytes = [Binary::PLACEABLE_KEY, Binary.uint16(placeable.handle, "handle"),
                 Binary.int16(placeable.left, "left"), Binary.int16(placeable.top, "top"),
                 Binary.int16(placeable.right, "right"), Binary.int16(placeable.bottom, "bottom"),
                 Binary.uint16(placeable.inch, "inch"), 0].pack("Vvs<4vV")
        bytes + [Binary.checksum(bytes)].pack("v")
      end

      def serialize_record(record)
        case record
        when Model::Wmf::Records::Eof then [3, 0].pack("Vv")
        when Model::Wmf::Records::MoveTo, Model::Wmf::Records::LineTo
          serialize_point(record)
        when Model::Wmf::Records::UnknownRecord then serialize_unknown(record)
        else raise SerializeError, "unsupported WMF record #{record.class}"
        end
      end

      def serialize_point(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        expected = record.is_a?(Model::Wmf::Records::MoveTo) ? 0x14 : 0x13
        raise SerializeError, "WMF point RecordFunction mismatch" unless function & 0xFF == expected

        [5, function, Binary.int16(record.y, "y"), Binary.int16(record.x, "x")].pack("Vvs<2")
      end

      def serialize_unknown(record)
        raw = record.raw_bytes
        words, function = raw.unpack("Vv")
        unless raw.bytesize >= 6 && raw.bytesize.even? && words == raw.bytesize / 2 && function == record.type_id &&
               !function.zero? && ![0x13, 0x14].include?(function & 0xFF)
          raise SerializeError, "invalid raw WMF record"
        end

        raw
      end
    end
  end
end
