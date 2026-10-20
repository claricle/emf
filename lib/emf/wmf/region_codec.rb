# frozen_string_literal: true

module Emf
  module Wmf
    module RegionCodec
      RECORDS = {
        0xFF => Model::Wmf::Records::CreateRegion,
        0x28 => Model::Wmf::Records::FillRegion,
        0x29 => Model::Wmf::Records::FrameRegion,
        0x2A => Model::Wmf::Records::InvertRegion,
        0x2B => Model::Wmf::Records::PaintRegion,
        0x2C => Model::Wmf::Records::SelectClipRegion,
        0x20 => Model::Wmf::Records::OffsetClipRgn,
        0x15 => Model::Wmf::Records::ExcludeClipRect,
        0x16 => Model::Wmf::Records::IntersectClipRect
      }.freeze
      FUNCTIONS = RECORDS.invert.freeze
      BOUNDS_FIELDS = %i[left top right bottom].freeze

      module_function

      def decode(raw, function, offset, &)
        klass = RECORDS.fetch(function & 0xFF)
        if klass == Model::Wmf::Records::CreateRegion
          fields, size = decode_region(raw.byteslice(6..), &)
        else
          size = klass::WIRE_FIELDS.length * 2
          yield "truncated region/clipping prefix" if raw.bytesize < 6 + size
          fields = klass::WIRE_FIELDS.zip(raw.byteslice(6, size).unpack(klass::WIRE_FORMAT)).to_h
        end
        klass.new(**fields, type_id: function, offset: offset, suffix: raw.byteslice((6 + size)..))
      end

      def decode_region(body, &)
        yield "truncated region header" if body.bytesize < 22
        next_in_chain, kind, object_count, size, count, max_scan, *bounds = body.unpack("v2Vs<7")
        if kind != 6 || size < 22 || size > body.bytesize || count.negative? || max_scan.negative? || count > (size - 22) / 8
          yield "invalid region header"
        end
        preflight_scans(body, size, count, max_scan, &)
        cursor = 22
        scans = Array.new(count) do
          points, top, bottom = body.byteslice(cursor, 6).unpack("v3")
          lines = body.byteslice(cursor + 6, points * 2).unpack("v*").each_slice(2).map do |left, right|
            Model::Wmf::Records::RegionScanLine.new(left: left, right: right)
          end
          cursor += 8 + (points * 2)
          Model::Wmf::Records::RegionScan.new(top: top, bottom: bottom, lines: lines)
        end
        [{ next_in_chain: next_in_chain, object_count: object_count,
           bounds: Model::Wmf::Records::RegionBounds.new(**BOUNDS_FIELDS.zip(bounds).to_h), scans: scans }, size]
      end

      def preflight_scans(body, size, count, max_scan)
        cursor = 22
        observed_max = 0
        count.times do
          yield "truncated region scan" if size - cursor < 8
          points = body.byteslice(cursor, 2).unpack1("v")
          scan_size = 8 + (points * 2)
          if points.odd? || scan_size > size - cursor || body.byteslice(cursor + scan_size - 2, 2).unpack1("v") != points
            yield "invalid region scan"
          end
          observed_max = [observed_max, points].max
          cursor += scan_size
        end
        yield "invalid region scan size or maximum" unless cursor == size && observed_max == max_scan
      end

      def byte_size(record)
        size = if record.is_a?(Model::Wmf::Records::CreateRegion)
                 22 + record.scans.sum { |scan| 8 + (scan.lines.length * 4) }
               else
                 record.class::WIRE_FIELDS.length * 2
               end
        6 + size + record.suffix.bytesize
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF region RecordFunction mismatch" unless function & 0xFF == FUNCTIONS[record.class]
        unless record.suffix.is_a?(String) && record.suffix.bytesize.even?
          raise SerializeError, "WMF region suffix must be a String with even length"
        end

        payload = encode_payload(record) + record.suffix.b
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def encode_payload(record)
        return encode_region(record) if record.is_a?(Model::Wmf::Records::CreateRegion)

        values = record.class::WIRE_FIELDS.zip(record.class::WIRE_TYPES).map do |field, type|
          Binary.public_send(type, record.public_send(field), field)
        end
        values.pack(record.class::WIRE_FORMAT)
      end

      def encode_region(record)
        unless record.bounds.is_a?(Model::Wmf::Records::RegionBounds) && record.scans.is_a?(Array)
          raise SerializeError, "WMF region requires RegionBounds and an array of scans"
        end

        count = Binary.integer(record.scans.length, 0..0x7FFF, "scan count")
        size, max_scan = region_layout(record.scans)
        bounds = BOUNDS_FIELDS.map { |field| Binary.int16(record.bounds.public_send(field), field) }
        header = [Binary.uint16(record.next_in_chain, "next_in_chain"), 6, Binary.uint32(record.object_count, "object_count"),
                  size, count, max_scan, *bounds].pack("v2Vs<7")
        header + record.scans.map { |scan| encode_scan(scan) }.join
      end

      def region_layout(scans)
        size = 22
        max_scan = 0
        scans.each do |scan|
          unless scan.is_a?(Model::Wmf::Records::RegionScan) && scan.lines.is_a?(Array)
            raise SerializeError, "WMF region scan requires RegionScan with an array of lines"
          end

          points = Binary.integer(scan.lines.length * 2, 0..0x7FFF, "scan point count")
          size = Binary.integer(size + 8 + (points * 2), 22..0x7FFF, "region size")
          max_scan = [max_scan, points].max
        end
        [size, max_scan]
      end

      def encode_scan(scan)
        points = scan.lines.length * 2
        prefix = [points, Binary.uint16(scan.top, "scan top"), Binary.uint16(scan.bottom, "scan bottom")].pack("v3")
        lines = scan.lines.map do |line|
          raise SerializeError, "WMF region line must be a RegionScanLine" unless line.is_a?(Model::Wmf::Records::RegionScanLine)

          [Binary.uint16(line.left, "scan left"), Binary.uint16(line.right, "scan right")].pack("v2")
        end
        prefix + lines.join + [points].pack("v")
      end
    end
  end
end
