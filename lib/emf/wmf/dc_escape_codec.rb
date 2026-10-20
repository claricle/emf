# frozen_string_literal: true

module Emf
  module Wmf
    module DcEscapeCodec
      RECORDS = {
        0x1E => Model::Wmf::Records::SaveDc,
        0x27 => Model::Wmf::Records::RestoreDc,
        0x05 => Model::Wmf::Records::SetRelAbs,
        0x26 => Model::Wmf::Records::Escape
      }.freeze
      FUNCTIONS = RECORDS.invert.freeze

      module_function

      def decode(raw, function, offset)
        klass = RECORDS.fetch(function & 0xFF)
        fields = { type_id: function, offset: offset }
        prefix = 6
        if klass == Model::Wmf::Records::RestoreDc
          prefix = 8
          yield "truncated RestoreDc prefix" if raw.bytesize < prefix
          fields[:saved_dc] = raw.byteslice(6, 2).unpack1("s<")
        elsif klass == Model::Wmf::Records::Escape
          yield "truncated Escape prefix" if raw.bytesize < 10
          fields[:escape_function], count = raw.byteslice(6, 4).unpack("v2")
          prefix = 10 + count + (count % 2)
          yield "truncated Escape data or padding" if raw.bytesize < prefix
          fields[:data] = raw.byteslice(10, count)
          fields[:padding] = raw.getbyte(10 + count) if count.odd?
        end
        klass.new(**fields, suffix: raw.byteslice(prefix..))
      end

      def byte_size(record)
        prefix = case record
                 when Model::Wmf::Records::RestoreDc then 8
                 when Model::Wmf::Records::Escape then 10 + record.data.bytesize + (record.data.bytesize % 2)
                 else 6
                 end
        prefix + record.suffix.bytesize
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF DC/Escape RecordFunction mismatch" unless function & 0xFF == FUNCTIONS[record.class]
        unless record.suffix.is_a?(String) && record.suffix.bytesize.even?
          raise SerializeError, "WMF DC/Escape suffix must be a String with even length"
        end

        payload = case record
                  when Model::Wmf::Records::RestoreDc then [Binary.int16(record.saved_dc, "saved_dc")].pack("s<")
                  when Model::Wmf::Records::Escape then encode_escape(record)
                  else "".b
                  end
        payload += record.suffix.b
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def encode_escape(record)
        raise SerializeError, "WMF Escape data must be a byte string" unless record.data.is_a?(String)

        count = Binary.uint16(record.data.bytesize, "Escape ByteCount")
        function = Binary.uint16(record.escape_function, "EscapeFunction")
        padding = "".b
        if count.odd?
          padding = [Binary.uint8(record.padding, "Escape padding")].pack("C")
        elsif !record.padding.nil?
          raise SerializeError, "WMF even Escape data must not have padding"
        end
        [function, count].pack("v2") + record.data.b + padding
      end
    end
  end
end
