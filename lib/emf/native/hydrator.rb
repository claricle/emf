# frozen_string_literal: true

require_relative "fields"

module Emf
  module Native
    class Hydrator
      SUPPORTED_TYPES = [
        2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
        37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 70, 71, 72, 73, 74,
        75, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 98, 115, 120
      ].freeze

      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
      end

      def call
        records = @snapshot.records.map { |record| hydrate_record(record) }
        emf_plus = records.filter_map do |record|
          wire = record.wire
          next unless wire.is_a?(Emr::Binary::Records::Comment) && wire.cb_data >= 4 && wire.data.start_with?("EMF+")

          wire.data.to_s.byteslice(4..)
        end.join.b
        Model::Metafile.new(
          format: emf_plus.empty? ? :emf : :emf_plus, header: Header.new.call(@snapshot.header, @snapshot.raw_header), records: records,
          errors: diagnostics, emf_plus: emf_plus.empty? ? nil : emf_plus,
          trailing: @snapshot.trailing + @snapshot.unframed
        )
      end

      private

      def hydrate_record(record)
        offset = record.fetch(:offset)
        length = record.fetch(:length)
        if offset.negative? || length < 8 || offset > @input.bytesize || length > @input.bytesize - offset
          raise FormatError, "invalid native record span"
        end

        raw = @input.byteslice(offset, length)

        klass, fields = wire_fields(record, raw)
        wire = klass.new(**fields, i_type: record.fetch(:type), n_size: record.fetch(:length))
        Fields.preserve_text_scales(wire, record.fetch(:payload)) if [74, 75].include?(record.fetch(:family))
        Model::Emr::Records::WireAdapter.new(wire: wire, offset: record.fetch(:offset))
      end

      def wire_fields(record, raw)
        payload = record.fetch(:payload)
        case record.fetch(:family)
        when 0 then raw_fields(record, raw)
        when 1 then eof_fields(payload, raw)
        when 2 then Fields.call(payload, 2)
        when 3, 45..53 then Fields.point_array(payload, record.fetch(:family))
        when 54..57 then Fields.multi_point_array(payload, record.fetch(:family))
        when 58, 59 then Fields.poly_draw(payload, record.fetch(:family))
        when 4 then comment_fields(payload, raw)
        when 33
          klass, fields = Fields.call(payload, 33)
          [klass, fields.merge(trailing: raw.byteslice(12..))]
        when 5..44, 60..80 then scalar_fields(record, raw)
        else raise FormatError, "unsupported native snapshot record family #{record.fetch(:family)}"
        end
      end

      def scalar_fields(record, raw)
        family = record.fetch(:family)
        return Fields.region(record.fetch(:payload), family, raw) if (76..80).cover?(family)

        return Fields.ext_text(record.fetch(:payload), family, raw) if [74, 75].include?(family)

        Fields.call(record.fetch(:payload), family)
      end

      def require_length(payload, length)
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == length
      end

      def raw_fields(record, raw)
        require_length(record.fetch(:payload), 0)
        type = record.fetch(:type)
        if !SUPPORTED_TYPES.include?(type) && Emr::Binary::Records.lookup(type) != Emr::Binary::Records::Raw
          raise FormatError, "native backend does not support typed EMR record #{type}"
        end

        [Emr::Binary::Records::Raw, { payload: raw.byteslice(8..) }]
      end

      def eof_fields(payload, raw)
        require_length(payload, 12)
        entries, offset, last = payload.unpack("V3")
        raise FormatError, "native backend does not support extended or paletted EOF records" unless entries.zero? && raw.bytesize == 20

        [Emr::Binary::Records::Eof, { n_pal_entries: entries, off_pal_entries: offset, n_size_last: last, body: "".b }]
      end

      def comment_fields(payload, raw)
        raise FormatError, "invalid native COMMENT payload" if payload.bytesize < 8

        count = payload.unpack1("Q<")
        require_length(payload, 8 + count)
        data = payload.byteslice(8..) + (raw.byteslice((12 + count)..) || "".b)
        [Emr::Binary::Records::Comment, { cb_data: count, data: data }]
      end

      def diagnostics
        @snapshot.diagnostics.map do |kind, has_type, type, reserved, offset, detail1, detail2|
          raise FormatError, "invalid native snapshot diagnostic" unless (1..4).cover?(kind) && (0..1).cover?(has_type) && reserved.zero?

          message = "native parse diagnostic #{kind} at offset #{offset} (#{detail1}, #{detail2})"
          ParseError.new(offset: offset, record_code: has_type == 1 ? type : nil, message: message)
        end
      end
    end
  end
end
