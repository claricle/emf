# frozen_string_literal: true

require_relative "fields"
require_relative "font_fields"
require_relative "gradient_fields"
require_relative "bitmap_fields"
require_relative "small_text_fields"
require_relative "lazy_wire"

module Emf
  module Native
    class Hydrator
      SUPPORTED_TYPES = [*(2..22), *(24..68), *(70..95), 98, 114, 115, 116, 118, 120].freeze

      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
      end

      def call
        records = @snapshot.records.map { |record| hydrate_record(record) }
        emf_plus = @snapshot.records.filter_map do |record|
          next unless record.fetch(:family) == 4

          _klass, fields = comment_fields(record.fetch(:payload), @input.byteslice(record.fetch(:offset), record.fetch(:length)))
          data = fields.fetch(:data)
          data.byteslice(4..) if fields.fetch(:cb_data) >= 4 && data.start_with?("EMF+")
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

        if record.fetch(:family) == 90
          wire = FontFields.new(record.fetch(:payload), raw).call
          return Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset)
        end

        klass, fields = wire_fields(record, raw)
        source = LazyWire.new(klass, fields, raw, record)
        Model::Emr::Records::WireAdapter.lazy(source: source, offset: offset)
      end

      def wire_fields(record, raw)
        payload = record.fetch(:payload)
        case record.fetch(:family)
        when 93..103 then BitmapFields.call(payload, record.fetch(:family), raw)
        when 0 then raw_fields(record, raw)
        when 1 then eof_fields(payload, raw)
        when 3, 45..53 then Fields.point_array(payload, record.fetch(:family))
        when 54..57 then Fields.multi_point_array(payload, record.fetch(:family))
        when 58, 59 then Fields.poly_draw(payload, record.fetch(:family))
        when 4 then comment_fields(payload, raw)
        when 33
          klass, fields = Fields.call(payload, 33)
          [klass, fields.merge(trailing: raw.byteslice(12..))]
        when 2, 5..44, 60..86, 91, 92 then scalar_fields(record, raw)
        else raise FormatError, "unsupported native snapshot record family #{record.fetch(:family)}"
        end
      end

      def scalar_fields(record, raw)
        family = record.fetch(:family)
        return PaletteFields.call(record.fetch(:payload), family, raw) if (82..86).cover?(family)

        return Fields.extended_pen(record.fetch(:payload), raw) if family == 81

        return Fields.region(record.fetch(:payload), family, raw) if (76..80).cover?(family)

        return Fields.ext_text(record.fetch(:payload), family, raw) if [74, 75].include?(family)

        if [91, 92].include?(family)
          klass, fields = Fields.call(record.fetch(:payload), family)
          fixed = family == 91 ? 24 : 16
          raise FormatError, "invalid native state record length" if raw.bytesize < fixed

          return [klass, fields.merge(trailing: raw.byteslice(fixed..))]
        end

        Fields.call(record.fetch(:payload), family)
      end

      def raw_fields(record, raw)
        raise FormatError, "invalid native typed payload length" unless record.fetch(:payload).empty?

        type = record.fetch(:type)
        return SmallTextFields.call(raw) if type == 108

        # These Ruby wire classes expose only an opaque body. Family 0 already
        # preserves it; materialize the registered class for body editing parity.
        return [Emr::Binary::Records.lookup(type), { body: raw.byteslice(8..) }] if [99, 100, 101, 122].include?(type)

        if !SUPPORTED_TYPES.include?(type) && Emr::Binary::Records.lookup(type) != Emr::Binary::Records::Raw
          raise FormatError, "native backend does not support typed EMR record #{type}"
        end

        [Emr::Binary::Records::Raw, { payload: raw.byteslice(8..) }]
      end

      def eof_fields(payload, raw)
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == 12

        entries, offset, last = payload.unpack("V3")
        raise FormatError, "native backend does not support extended or paletted EOF records" unless entries.zero? && raw.bytesize == 20

        [Emr::Binary::Records::Eof, { n_pal_entries: entries, off_pal_entries: offset, n_size_last: last, body: "".b }]
      end

      def comment_fields(payload, raw)
        raise FormatError, "invalid native COMMENT payload" if payload.bytesize < 8

        count = payload.unpack1("Q<")
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == 8 + count

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
