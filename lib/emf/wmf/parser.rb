# frozen_string_literal: true

module Emf
  module Wmf
    module Parser
      module_function

      def call(bytes)
        ResourceLimits.check!(:input_bytes, Binary::MAX_INPUT_BYTES, bytes.bytesize)

        placeable, start = read_placeable(bytes)
        header = read_header(bytes, start, placeable)
        records = read_records(bytes, start + Binary::HEADER_BYTES, bytes.bytesize)
        Binary.validate_objects(records, header.number_of_objects) do |record, message|
          parse_error(record.offset, record.type_id, message)
        end
        # The walk is bounded by the real input and ends at the first EOF record, so a header Size or MaxRecord that
        # disagrees with the records is recovered: the model is kept and the drift is recorded in errors.
        stop = records.last.offset + (records.last.declared_size_words * 2)
        Model::Metafile.new(format: :wmf, header: header, records: records, errors: Evidence.drift_errors(bytes),
                            trailing: bytes.byteslice(stop..).to_s)
      end

      def read_placeable(bytes)
        return [nil, 0] unless bytes.bytesize >= 4 && bytes.unpack1("V") == Binary::PLACEABLE_KEY
        raise FormatError, "truncated WMF placeable header" if bytes.bytesize < Binary::PLACEABLE_BYTES

        _key, handle, left, top, right, bottom, inch, reserved, checksum = bytes.unpack("Vvs<4vVv")
        raise FormatError, "WMF placeable reserved field must be zero" unless reserved.zero?
        raise FormatError, "WMF placeable checksum mismatch" unless checksum == Binary.checksum(bytes.byteslice(0, 20))

        header = Model::Wmf::PlaceableHeader.new(handle: handle, left: left, top: top, right: right, bottom: bottom,
                                                 inch: inch, checksum: checksum)
        [header, Binary::PLACEABLE_BYTES]
      end

      def read_header(bytes, start, placeable)
        raise FormatError, "truncated WMF standard header" if bytes.bytesize - start < Binary::HEADER_BYTES

        type, header_size, version, size, objects, max_record, members = bytes.byteslice(start, Binary::HEADER_BYTES).unpack("v3VvVv")
        raise FormatError, "invalid WMF Type" unless [1, 2].include?(type)
        raise FormatError, "invalid WMF HeaderSize" unless header_size == 9
        raise FormatError, "invalid WMF Version" unless [0x100, 0x300].include?(version)
        raise FormatError, "WMF on-disk placeable handle must be zero" if type == 2 && placeable && !placeable.handle.zero?

        Model::Wmf::Header.new(type: type, version: version, size_words: size, number_of_objects: objects,
                               max_record_words: max_record, number_of_members: members, placeable: placeable)
      end

      def read_records(bytes, offset, limit)
        records = []
        while offset < limit
          ResourceLimits.check!(:record_count, Binary::MAX_RECORDS, records.length + 1)
          parse_error(offset, nil, "truncated record header") if limit - offset < 6
          words, function = bytes.byteslice(offset, 6).unpack("Vv")
          parse_error(offset, function, "invalid record length #{words}") if words < 3 || words > (limit - offset) / 2
          raw = bytes.byteslice(offset, words * 2)
          record = decode_record(raw, function, offset).declare_size(words)
          records << record
          offset += raw.bytesize
          return records if record.is_a?(Model::Wmf::Records::Eof)
        end
        parse_error(offset, nil, "missing EOF record")
      end

      def decode_record(raw, function, offset)
        if function.zero?
          parse_error(offset, function, "invalid EOF length") unless raw.bytesize == 6
          return Model::Wmf::Records::Eof.new(offset: offset)
        end
        return decode_prefix_record(raw, function, offset) if Binary::PREFIX_FUNCTIONS.include?(function & 0xFF)
        return decode_object(raw, function, offset) if Binary::OBJECT_RECORDS.key?(function & 0xFF)
        if Binary::TEXT_FUNCTIONS.include?(function & 0xFF)
          return TextCodec.decode(raw, function, offset) { |message| parse_error(offset, function, message) }
        end
        return decode_point_array(raw, function, offset) if Binary::POINT_ARRAY_RECORDS.key?(function & 0xFF)

        record_class = Binary::FIXED_RECORDS[function & 0xFF]
        return Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw, offset: offset) unless record_class

        fields = record_class::WIRE_FIELDS
        parse_error(offset, function, "invalid fixed record length") unless raw.bytesize == 6 + (fields.length * 2)
        values = raw.byteslice(6..).unpack("s<*")
        record_class.new(**fields.zip(values).to_h, type_id: function, offset: offset)
      end

      def decode_prefix_record(raw, function, offset)
        return decode_font(raw, function, offset) if function & 0xFF == 0xFB
        return decode_state(raw, function, offset) if Binary::STATE_RECORDS.key?(function & 0xFF)

        codec = [PaletteCodec, RegionCodec, BrushCodec, BitmapCodec, GeometryCodec, DcEscapeCodec]
                .find { |candidate| candidate::RECORDS.key?(function & 0xFF) }
        codec.decode(raw, function, offset) { |message| parse_error(offset, function, message) }
      end

      def decode_state(raw, function, offset)
        record_class = Binary::STATE_RECORDS.fetch(function & 0xFF)
        prefix_size = 6 + record_class::PAYLOAD_BYTES
        parse_error(offset, function, "invalid state record length") if raw.bytesize < prefix_size
        values = raw.byteslice(6, record_class::PAYLOAD_BYTES).unpack(record_class::WIRE_FORMAT)
        fields = record_class::WIRE_FIELDS.zip(values).to_h
        record_class.new(**fields, type_id: function, offset: offset, suffix: raw.byteslice(prefix_size..))
      end

      def decode_font(raw, function, offset)
        record_class = Model::Wmf::Records::CreateFontIndirect
        prefix_size = 6 + record_class::PAYLOAD_BYTES
        parse_error(offset, function, "invalid font record length") if raw.bytesize < prefix_size
        values = raw.byteslice(6, record_class::PAYLOAD_BYTES).unpack(record_class::WIRE_FORMAT)
        fields = record_class::WIRE_FIELDS.zip(values).to_h
        record_class.new(**fields, type_id: function, offset: offset, suffix: raw.byteslice(prefix_size..))
      end

      def decode_object(raw, function, offset)
        record_class = Binary::OBJECT_RECORDS.fetch(function & 0xFF)
        parse_error(offset, function, "invalid object record length") unless raw.bytesize == 6 + record_class::PAYLOAD_BYTES
        values = raw.byteslice(6..).unpack(record_class::WIRE_FORMAT)
        record_class.new(**record_class::WIRE_FIELDS.zip(values).to_h, type_id: function, offset: offset)
      end

      def decode_point_array(raw, function, offset)
        parse_error(offset, function, "missing point array count") if raw.bytesize < 8
        record_class = Binary::POINT_ARRAY_RECORDS.fetch(function & 0xFF)
        if record_class == Model::Wmf::Records::PolyPolygon
          polygon_count = raw.byteslice(6, 2).unpack1("v")
          points_start = 8 + (polygon_count * 2)
          parse_error(offset, function, "truncated polygon counts") if raw.bytesize < points_start
          counts = raw.byteslice(8, polygon_count * 2).unpack("v*")
          point_count = counts.sum
        else
          point_count = raw.byteslice(6, 2).unpack1("s<")
          minimum = record_class == Model::Wmf::Records::Polygon ? 2 : 0
          parse_error(offset, function, "invalid point count") if point_count < minimum
          points_start = 8
        end
        parse_error(offset, function, "point array length mismatch") unless raw.bytesize == points_start + (point_count * 4)

        points = raw.byteslice(points_start..).unpack("s<*").each_slice(2).map do |x, y|
          Model::Wmf::Records::PointS.new(x: x, y: y)
        end
        fields = { points: points, type_id: function, offset: offset }
        fields[:points_per_polygon] = counts if counts
        record_class.new(**fields)
      end

      def parse_error(offset, function, message)
        raise ParseError.new(offset: offset, record_code: function, message: "WMF #{message} at offset #{offset}")
      end
    end
  end
end
