# frozen_string_literal: true

module Emf
  module Native
    class Hydrator
      SUPPORTED_TYPES = [4, 9, 10, 11, 12, 13, 14, 17, 18, 19, 20, 21, 26, 27, 70].freeze

      WIRE_FIELDS = {
        5 => [Emr::Binary::Records::SetBkMode, :bk_mode],
        6 => [Emr::Binary::Records::SetPolyFillMode, :poly_fill_mode],
        7 => [Emr::Binary::Records::SetRop2, :rop2],
        8 => [Emr::Binary::Records::SetStretchBltMode, :stretch_mode],
        9 => [Emr::Binary::Records::SetWindowExtEx, :extent, %i[cx cy]],
        10 => [Emr::Binary::Records::SetWindowOrgEx, :origin, %i[x y]],
        11 => [Emr::Binary::Records::SetViewportExtEx, :extent, %i[cx cy]],
        12 => [Emr::Binary::Records::SetViewportOrgEx, :origin, %i[x y]],
        13 => [Emr::Binary::Records::SetBrushOrgEx, :ptl_origin, %i[x y]],
        14 => [Emr::Binary::Records::OffsetClipRgn, :ptl_offset, %i[x y]],
        15 => [Emr::Binary::Records::MoveToEx, :origin, %i[x y]]
      }.freeze

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
        Model::Emr::Records::WireAdapter.new(wire: wire, offset: record.fetch(:offset))
      end

      def wire_fields(record, raw)
        payload = record.fetch(:payload)
        case record.fetch(:family)
        when 0 then raw_fields(record, raw)
        when 1 then eof_fields(payload, raw)
        when 2 then typed_fields(payload, Emr::Binary::Records::SetMapMode, :map_mode)
        when 3 then polyline_fields(payload)
        when 4 then comment_fields(payload, raw)
        when 5..15 then typed_fields(payload, *WIRE_FIELDS.fetch(record.fetch(:family)))
        else raise FormatError, "unsupported native snapshot record family #{record.fetch(:family)}"
        end
      end

      def require_length(payload, length)
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == length
      end

      def typed_fields(payload, klass, field, axes = nil)
        require_length(payload, axes ? 8 : 4)
        value = axes ? axes.zip(payload.unpack("l<2")).to_h : payload.unpack1("V")
        [klass, { field => value }]
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

      def polyline_fields(payload)
        raise FormatError, "invalid native POLYLINE payload" if payload.bytesize < 24

        count = payload.byteslice(16, 8).unpack1("Q<")
        require_length(payload, 24 + (count * 8))
        raise FormatError, "native POLYLINE exceeds Ruby model array limit" if count > 1_000_000

        bounds = %i[left top right bottom].zip(payload.unpack("l<4")).to_h
        points = payload.byteslice(24..).unpack("l<*").each_slice(2).map { |x, y| { x: x, y: y } }
        [Emr::Binary::Records::Polyline, { rcl_bounds: bounds, cptl: count, aptl: points }]
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
