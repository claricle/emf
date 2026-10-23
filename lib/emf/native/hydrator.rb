# frozen_string_literal: true

require_relative "fields"
require_relative "font_fields"
require_relative "gradient_fields"
require_relative "bitmap_fields"
require_relative "small_text_fields"
require_relative "poly_text_fields"
require_relative "lazy_wire"
require_relative "diagnostics"
require_relative "emf_plus_source"

module Emf
  module Native
    class Hydrator
      SUPPORTED_TYPES = [*(2..68), *(70..98), 114, 115, 116, 118, 120].freeze
      OPAQUE_BODY_TYPES = [23, 96, 97, *(99..106), *(109..113), 119, 121, 122].freeze

      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
        # Filled wires read their fields from this frozen view, as Ruby-parsed wires do.
        @data = input.frozen? ? input : input.dup.freeze
      end

      def call
        diagnostics = Diagnostics.new(@snapshot, @input)
        table = @snapshot.table
        plus_candidates = []
        records = Array.new(@snapshot.record_count) do |index|
          plus_candidates << index if diagnostics.recovered?(table[(index * 5) + 1]) || table[(index * 5) + 3] >> 32 == 4
          diagnostics.adapter_at(table[(index * 5) + 1]) || hydrate_at(index, table)
        end
        emf_plus = emf_plus_stream(diagnostics, plus_candidates)
        Model::Metafile.new(
          format: emf_plus.empty? ? :emf : :emf_plus, header: Header.new.call(@snapshot.header, @snapshot.raw_header), records: records,
          errors: diagnostics.errors, emf_plus: emf_plus.empty? ? nil : emf_plus,
          trailing: @snapshot.trailing + @snapshot.unframed, emf_plus_source: (EmfPlusSource.call(@input) unless emf_plus.empty?)
        )
      end

      private

      def hydrate_at(index, table)
        base = index * 5
        offset = table[base + 1]
        length = table[base + 2]
        raise FormatError, "invalid native record span" unless length >= 8 && offset >= 0 && offset <= @input.bytesize - length

        filled = FilledWire.for(table[base + 3], offset, length, @data)
        return Model::Emr::Records::WireAdapter.lazy(source: filled, offset: offset) if filled

        hydrate_record(@snapshot.record(index), offset, length)
      end

      def hydrate_record(record, offset, length)
        raw = @input.byteslice(offset, length)

        if record.fetch(:family) == 90
          wire = FontFields.new(record.fetch(:payload), raw).call
          return Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset)
        end

        klass, fields = wire_fields(record, raw)
        Model::Emr::Records::WireAdapter.lazy(source: LazyWire.new(klass, fields, raw, record), offset: offset)
      end

      def wire_fields(record, raw)
        payload = record.fetch(:payload)
        family = record.fetch(:family)
        case family
        when 93..103 then BitmapFields.call(payload, family, raw)
        when 0 then raw_fields(record, raw)
        when 1 then Fields.eof(payload, raw)
        when 3, 45..53 then Fields.point_array(payload, record.fetch(:family))
        when 54..57 then Fields.multi_point_array(payload, record.fetch(:family))
        when 58, 59 then Fields.poly_draw(payload, record.fetch(:family))
        when 4 then Fields.comment(payload, raw)
        when 33
          klass, fields = Fields.call(payload, 33)
          [klass, fields.merge(trailing: raw.byteslice(12..))]
        when 2, 5..44, 60..86, 91, 92, 104..106 then scalar_fields(record, raw)
        else raise FormatError, "unsupported native snapshot record family #{record.fetch(:family)}"
        end
      end

      def scalar_fields(record, raw)
        family = record.fetch(:family)
        return PolyTextFields.call(record.fetch(:payload), family, raw, record.fetch(:type)) if (104..106).cover?(family)

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

        # Body-backed public classes also preserve malformed recognized records.
        # Their family-0 snapshot carries no semantic fields; diagnostics report recovery.
        return [Emr::Binary::Records.lookup(type), { body: raw.byteslice(8..) }] if OPAQUE_BODY_TYPES.include?(type)

        if !SUPPORTED_TYPES.include?(type) && Emr::Binary::Records.lookup(type) != Emr::Binary::Records::Raw
          raise FormatError, "native backend does not support typed EMR record #{type}"
        end

        [Emr::Binary::Records::Raw, { payload: raw.byteslice(8..) }]
      end

      # Only recovered records and COMMENTs can carry EMF+ bytes, in record order.
      def emf_plus_stream(diagnostics, candidates)
        table = @snapshot.table
        candidates.filter_map do |index|
          offset = table[(index * 5) + 1]
          next diagnostics.emf_plus_at(offset) if diagnostics.recovered?(offset)
          next unless table[(index * 5) + 3] >> 32 == 4

          _klass, fields = Fields.comment(@snapshot.payload(index), @input.byteslice(offset, table[(index * 5) + 2]))
          data = fields.fetch(:data)
          data.byteslice(4..) if fields.fetch(:cb_data) >= 4 && data.start_with?("EMF+")
        end.join.b
      end
    end
  end
end
