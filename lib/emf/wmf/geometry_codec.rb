# frozen_string_literal: true

module Emf
  module Wmf
    module GeometryCodec
      RECORDS = {
        0x10 => Model::Wmf::Records::ScaleWindowExt,
        0x12 => Model::Wmf::Records::ScaleViewportExt,
        0x19 => Model::Wmf::Records::FloodFill,
        0x1F => Model::Wmf::Records::SetPixel,
        0x48 => Model::Wmf::Records::ExtFloodFill,
        0x1D => Model::Wmf::Records::PatBlt
      }.freeze
      FUNCTIONS = RECORDS.invert.freeze

      module_function

      def decode(raw, function, offset)
        klass = RECORDS.fetch(function & 0xFF)
        prefix = 6 + klass::PAYLOAD_BYTES
        yield "truncated geometry prefix" if raw.bytesize < prefix
        fields = klass::WIRE_FIELDS.zip(raw.byteslice(6, klass::PAYLOAD_BYTES).unpack(klass::WIRE_FORMAT)).to_h
        yield "invalid extended flood fill mode" if klass == Model::Wmf::Records::ExtFloodFill && fields[:mode] > 1
        klass.new(**fields, type_id: function, offset: offset, suffix: raw.byteslice(prefix..))
      end

      def byte_size(record)
        6 + record.class::PAYLOAD_BYTES + record.suffix.bytesize
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF geometry RecordFunction mismatch" unless function & 0xFF == FUNCTIONS[record.class]
        unless record.suffix.is_a?(String) && record.suffix.bytesize.even?
          raise SerializeError, "WMF geometry suffix must be a String with even length"
        end
        raise SerializeError, "WMF geometry too large" if byte_size(record) > Binary::MAX_INPUT_BYTES

        values = record.class::WIRE_FIELDS.zip(record.class::WIRE_TYPES).map do |field, type|
          Binary.public_send(type, record.public_send(field), field)
        end
        raise SerializeError, "invalid WMF extended flood fill mode" if record.is_a?(Model::Wmf::Records::ExtFloodFill) && record.mode > 1

        payload = values.pack(record.class::WIRE_FORMAT) + record.suffix.b
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end
    end
  end
end
