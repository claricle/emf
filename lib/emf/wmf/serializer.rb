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
        capacity = Binary.uint16(metafile.header.number_of_objects, "NumberOfObjects")
        Binary.validate_objects(metafile.records, capacity) do |_record, message|
          raise SerializeError, "WMF #{message}"
        end
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
        when Model::Wmf::Records::PointRecord, Model::Wmf::Records::RectangleRecord, Model::Wmf::Records::OffsetRecord
          serialize_fixed(record)
        when Model::Wmf::Records::ObjectRecord then serialize_object(record)
        when Model::Wmf::Records::TextOut then TextCodec.encode(record)
        when Model::Wmf::Records::PointArrayRecord then serialize_point_array(record)
        when Model::Wmf::Records::UnknownRecord then serialize_unknown(record)
        else raise SerializeError, "unsupported WMF record #{record.class}"
        end
      end

      def serialize_fixed(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        expected = Binary::FIXED_FUNCTIONS[record.class]
        raise SerializeError, "WMF fixed RecordFunction mismatch" unless function & 0xFF == expected

        values = record.class::WIRE_FIELDS.map { |field| Binary.int16(record.public_send(field), field) }
        [3 + values.length, function, *values].pack("Vvs<*")
      end

      def serialize_object(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        expected = Binary::OBJECT_FUNCTIONS[record.class]
        raise SerializeError, "WMF object RecordFunction mismatch" unless function & 0xFF == expected

        values = record.class::WIRE_FIELDS.zip(record.class::WIRE_TYPES).map do |field, type|
          Binary.public_send(type, record.public_send(field), field)
        end
        payload = values.pack(record.class::WIRE_FORMAT)
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def serialize_point_array(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        expected = Binary::POINT_ARRAY_FUNCTIONS[record.class]
        raise SerializeError, "WMF point array RecordFunction mismatch" unless function & 0xFF == expected
        raise SerializeError, "WMF points must be an array" unless record.points.is_a?(Array)

        counts = serialize_point_counts(record)
        coordinates = record.points.flat_map do |point|
          raise SerializeError, "WMF point must be a PointS" unless point.is_a?(Model::Wmf::Records::PointS)

          [Binary.int16(point.x, "x"), Binary.int16(point.y, "y")]
        end
        payload = counts + coordinates.pack("s<*")
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def serialize_point_counts(record)
        unless record.is_a?(Model::Wmf::Records::PolyPolygon)
          count = Binary.int16(record.points.length, "NumberOfPoints")
          raise SerializeError, "WMF Polygon requires at least two points" if record.is_a?(Model::Wmf::Records::Polygon) && count < 2

          return [count].pack("s<")
        end
        counts = record.points_per_polygon
        raise SerializeError, "WMF polygon counts must be an array" unless counts.is_a?(Array)

        polygon_count = Binary.uint16(counts.length, "NumberOfPolygons")
        counts.each { |count| Binary.uint16(count, "PointsPerPolygon") }
        raise SerializeError, "WMF polygon point count mismatch" unless counts.sum == record.points.length

        [polygon_count, *counts].pack("v*")
      end

      def serialize_unknown(record)
        raw = record.raw_bytes
        words, function = raw.unpack("Vv")
        unless raw.bytesize >= 6 && raw.bytesize.even? && words == raw.bytesize / 2 && function == record.type_id &&
               !function.zero? && !Binary::OBJECT_RECORDS.key?(function & 0xFF) && !Binary::TEXT_FUNCTIONS.include?(function & 0xFF) &&
               !Binary::FIXED_RECORDS.key?(function & 0xFF) && !Binary::POINT_ARRAY_RECORDS.key?(function & 0xFF)
          raise SerializeError, "invalid raw WMF record"
        end

        raw
      end
    end
  end
end
