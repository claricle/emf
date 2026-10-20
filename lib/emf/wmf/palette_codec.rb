# frozen_string_literal: true

module Emf
  module Wmf
    module PaletteCodec
      RECORDS = {
        0xF7 => Model::Wmf::Records::CreatePalette,
        0x37 => Model::Wmf::Records::SetPalEntries,
        0x36 => Model::Wmf::Records::AnimatePalette,
        0x34 => Model::Wmf::Records::SelectPalette,
        0x39 => Model::Wmf::Records::ResizePalette,
        0x35 => Model::Wmf::Records::RealizePalette
      }.freeze
      FUNCTIONS = RECORDS.invert.freeze
      ENTRY_FIELDS = %i[red green blue flags].freeze

      module_function

      def decode(raw, function, offset)
        klass = RECORDS.fetch(function & 0xFF)
        fields = { type_id: function, offset: offset }
        prefix = 6
        if klass <= Model::Wmf::Records::PaletteRecord
          yield "truncated palette prefix" if raw.bytesize < 10
          start, count = raw.byteslice(6, 4).unpack("v2")
          prefix = 10 + (count * 4)
          yield "truncated palette entries" if raw.bytesize < prefix
          fields[:start] = start
          fields[:entries] = raw.byteslice(10, count * 4).unpack("C*").each_slice(4).map do |values|
            Model::Wmf::Records::PaletteEntry.new(**ENTRY_FIELDS.zip(values).to_h)
          end
        elsif klass != Model::Wmf::Records::RealizePalette
          prefix = 8
          yield "truncated palette prefix" if raw.bytesize < prefix
          field = klass == Model::Wmf::Records::SelectPalette ? :object_index : :entry_count
          fields[field] = raw.byteslice(6, 2).unpack1("v")
        end
        klass.new(**fields, suffix: raw.byteslice(prefix..))
      end

      def byte_size(record)
        prefix = if record.is_a?(Model::Wmf::Records::PaletteRecord)
                   10 + (record.entries.length * 4)
                 elsif record.is_a?(Model::Wmf::Records::RealizePalette)
                   6
                 else
                   8
                 end
        prefix + record.suffix.bytesize
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF palette RecordFunction mismatch" unless function & 0xFF == FUNCTIONS[record.class]
        unless record.suffix.is_a?(String) && record.suffix.bytesize.even?
          raise SerializeError, "WMF palette suffix must be a String with even length"
        end

        payload = encode_payload(record) + record.suffix.b
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def encode_payload(record)
        case record
        when Model::Wmf::Records::PaletteRecord
          raise SerializeError, "WMF palette entries must be an array" unless record.entries.is_a?(Array)

          start = Binary.uint16(record.start, "start")
          count = Binary.uint16(record.entries.length, "entry count")
          entries = record.entries.map do |entry|
            raise SerializeError, "WMF palette entry must be a PaletteEntry" unless entry.is_a?(Model::Wmf::Records::PaletteEntry)

            ENTRY_FIELDS.map { |field| Binary.uint8(entry.public_send(field), field) }.pack("C4")
          end
          [start, count].pack("v2") + entries.join
        when Model::Wmf::Records::SelectPalette
          [Binary.uint16(record.object_index, "object_index")].pack("v")
        when Model::Wmf::Records::ResizePalette
          [Binary.uint16(record.entry_count, "entry_count")].pack("v")
        else "".b
        end
      end
    end
  end
end
