# frozen_string_literal: true

module Emf
  module Wmf
    module BitmapCodec
      RECORDS = { 0x22 => Model::Wmf::Records::BitBlt, 0x40 => Model::Wmf::Records::DibBitBlt,
                  0x23 => Model::Wmf::Records::StretchBlt, 0x41 => Model::Wmf::Records::DibStretchBlt,
                  0x33 => Model::Wmf::Records::SetDibToDev, 0x43 => Model::Wmf::Records::StretchDib }.freeze
      FUNCTIONS = RECORDS.invert.freeze
      BLT_FIELDS = %i[raster_operation source_y source_x height width destination_y destination_x reserved].freeze
      STRETCH_FIELDS = %i[raster_operation source_height source_width source_y source_x destination_height destination_width
                          destination_y destination_x reserved].freeze
      SET_FIELDS = %i[color_usage scan_count start_scan source_y source_x height width destination_y destination_x].freeze
      DIB_FIELDS = (STRETCH_FIELDS[0, 1] + [:color_usage] + STRETCH_FIELDS[1, 8]).freeze
      FIELDS = { 0x22 => BLT_FIELDS, 0x40 => BLT_FIELDS, 0x23 => STRETCH_FIELDS, 0x41 => STRETCH_FIELDS,
                 0x33 => SET_FIELDS, 0x43 => DIB_FIELDS }.freeze

      FORMATS = { uint32: "V", uint16: "v", int16: "s<" }.freeze

      module_function

      def optional?(kind)
        [0x22, 0x40, 0x23, 0x41].include?(kind)
      end

      def field_type(kind, field)
        return :uint32 if field == :raster_operation
        return :uint16 if kind == 0x33 || %i[color_usage reserved].include?(field)

        :int16
      end

      def wire_fields(kind, absent)
        fields = FIELDS.fetch(kind).reject { |field| field == :reserved }
        fields.insert(fields.index([0x22, 0x40].include?(kind) ? :height : :destination_height), :reserved) if absent
        fields
      end

      def format_for(kind, fields)
        fields.map { |field| FORMATS.fetch(field_type(kind, field)) }.join
      end

      def decode(raw, function, offset)
        kind = function & 0xFF
        absent = optional?(kind) && (raw.bytesize - 6) / 2 == function >> 8
        names = wire_fields(kind, absent)
        format = format_for(kind, names)
        length = names.sum { |field| field == :raster_operation ? 4 : 2 }
        yield "truncated bitmap transfer prefix" if raw.bytesize < 6 + length
        fields = names.zip(raw.byteslice(6, length).unpack(format)).to_h
        fields[:reserved] ||= 0 if optional?(kind)
        if absent
          fields[:bitmap] = nil
          fields[:suffix] = raw.byteslice((6 + length)..)
        else
          yield "empty bitmap transfer source" unless raw.bytesize > 6 + length
          fields[:bitmap] = raw.byteslice((6 + length)..)
          fields[:suffix] = "".b
        end
        RECORDS.fetch(kind).new(**fields, type_id: function, offset: offset)
      end

      def byte_size(record)
        kind = FUNCTIONS.fetch(record.class)
        prefix = wire_fields(kind, optional?(kind) && record.bitmap.nil?).sum { |field| field == :raster_operation ? 4 : 2 }
        6 + prefix + (record.bitmap&.bytesize || 0) + record.suffix.bytesize
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        kind = FUNCTIONS.fetch(record.class)
        raise SerializeError, "WMF bitmap RecordFunction mismatch" unless function & 0xFF == kind

        fields = FIELDS.fetch(kind).to_h { |field| [field, record.public_send(field)] }
        fields[:bitmap] = record.bitmap
        fields[:suffix] = record.suffix
        body = encode_fields(fields, function)
        [3 + (body.bytesize / 2), function].pack("Vv") + body
      end

      def encode_fields(fields, function)
        kind = function & 0xFF
        FIELDS.fetch(kind).each { |field| Binary.public_send(field_type(kind, field), fields.fetch(field), field) }
        absent = optional?(kind) && fields[:bitmap].nil?
        image, suffix = source_bytes(fields, kind, absent)
        names = wire_fields(kind, absent)
        size = names.sum { |field| field == :raster_operation ? 4 : 2 } + image.bytesize + suffix.bytesize
        validate_layout(kind, absent, size, function)

        names.map { |field| fields.fetch(field) }.pack(format_for(kind, names)) + image.b + suffix.b
      end

      def source_bytes(fields, kind, absent)
        suffix = fields.fetch(:suffix, "".b)
        validate_bytes(suffix)
        raise SerializeError, "WMF bitmap suffix requires absent source" unless absent || suffix.empty?
        raise SerializeError, "WMF present bitmap reserved word must be zero" if optional?(kind) && !absent && fields[:reserved] != 0

        image = absent ? "".b : fields[:bitmap]
        validate_bytes(image)
        raise SerializeError, "empty WMF bitmap source" if !absent && image.empty?

        [image, suffix]
      end

      def validate_layout(kind, absent, size, function)
        raise SerializeError, "WMF bitmap too large" if size > Binary::MAX_INPUT_BYTES - 6
        raise SerializeError, "ambiguous WMF bitmap source layout" if optional?(kind) && absent != (size / 2 == function >> 8)
      end

      def validate_bytes(value)
        return if value.is_a?(String) && value.bytesize.even? && value.bytesize <= Binary::MAX_INPUT_BYTES - 6

        raise SerializeError, "invalid WMF bitmap bytes"
      end
    end
  end
end
