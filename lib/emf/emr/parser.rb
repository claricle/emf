# frozen_string_literal: true

require "stringio"

module Emf
  module Emr
    module Parser
      module_function

      def call(bytes)
        raise FormatError, "input too large (#{bytes.bytesize} > #{MAX_INPUT_BYTES}); refusing to parse" if bytes.bytesize > MAX_INPUT_BYTES
        raise FormatError, "not an EMF file (signature mismatch)" unless Emf::Detector.call(bytes) == :emf

        io = StringIO.new(bytes, "rb")
        header_wire = read_header(io)
        header = Model::Emr::Header.from_wire(header_wire)

        records = []
        errors = []
        emf_plus_bytes = +""
        trailing = +""

        until io.eof?
          offset = io.pos
          wire, suffix = read_record(io, offset, errors)
          if wire.nil?
            trailing << bytes.byteslice(offset..)
            break
          end

          records << Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset, suffix: suffix)
          emf_plus_bytes << extract_emf_plus(wire) if wire.is_a?(Emf::Emr::Binary::Records::Comment)

          if wire.is_a?(Emf::Emr::Binary::Records::Eof)
            trailing << io.read until io.eof?
            break
          end
        end

        Model::Metafile.new(
          format: emf_plus_bytes.empty? ? :emf : :emf_plus,
          header: header,
          records: records,
          errors: errors,
          emf_plus: emf_plus_bytes.empty? ? nil : emf_plus_bytes,
          trailing: trailing
        )
      end

      def read_header(io)
        # Peek at the first 8 bytes to determine the record's nSize.
        head = io.read(8)
        raise FormatError, "truncated EMF header" if head.nil? || head.bytesize < 8

        _type, n_size = head.unpack("VV")
        raise FormatError, "EMF header nSize too small: #{n_size}" if n_size < 8

        io.seek(0)
        full = io.read(n_size)
        if full.nil? || full.bytesize < n_size
          raise FormatError,
                "truncated EMF header (claimed #{n_size}, got #{full&.bytesize || 0})"
        end

        Emf::Emr::Binary::Header.read(full)
      end

      # Per-type byte-size validation for records with variable-length arrays.
      # If the declared count exceeds what nSize can hold, the bytes are
      # corrupt and we should preserve them as Raw rather than letting bindata
      # allocate a giant array. The element size is bytes per array entry.
      VARIABLE_ARRAY_RECORDS = {
        Binary::TypeCodes::EXTCREATEPEN => { count_offset: 48, element_size: 4 },
        Binary::TypeCodes::CREATEPALETTE => { count_offset: 14, count_width: 2, element_size: 4 },
        Binary::TypeCodes::SETPALETTEENTRIES => { count_offset: 16, element_size: 4 },
        Binary::TypeCodes::POLYGON => { count_offset: 24, element_size: 8 },
        Binary::TypeCodes::POLYLINE => { count_offset: 24, element_size: 8 },
        Binary::TypeCodes::POLYBEZIER => { count_offset: 24, element_size: 8 },
        Binary::TypeCodes::POLYBEZIERTO => { count_offset: 24, element_size: 8 },
        Binary::TypeCodes::POLYLINETO => { count_offset: 24, element_size: 8 },
        Binary::TypeCodes::POLYGON16 => { count_offset: 24, element_size: 4 },
        Binary::TypeCodes::POLYLINE16 => { count_offset: 24, element_size: 4 },
        Binary::TypeCodes::POLYBEZIER16 => { count_offset: 24, element_size: 4 },
        Binary::TypeCodes::POLYBEZIERTO16 => { count_offset: 24, element_size: 4 },
        Binary::TypeCodes::POLYLINETO16 => { count_offset: 24, element_size: 4 },
        Binary::TypeCodes::POLYDRAW => { count_offset: 24, element_size: 9 },
        Binary::TypeCodes::POLYDRAW16 => { count_offset: 24, element_size: 5 },
        # Multi-polygon records have TWO variable arrays: aPolyCounts
        # (nPolys uint32s, 4 bytes each) and aptl/apts (cTotal entries).
        # The count1 entries are ALWAYS uint32 (4 bytes); element_size
        # applies only to the count2 (point) array.
        Binary::TypeCodes::POLYPOLYGON => { count_offset: 24, count2_offset: 28, element_size: 8 },
        Binary::TypeCodes::POLYPOLYLINE => { count_offset: 24, count2_offset: 28, element_size: 8 },
        Binary::TypeCodes::POLYPOLYGON16 => { count_offset: 24, count2_offset: 28, element_size: 4 },
        Binary::TypeCodes::POLYPOLYLINE16 => { count_offset: 24, count2_offset: 28, element_size: 4 }
      }.freeze

      MAX_SANE_ARRAY_LENGTH = 1_000_000
      # Bounds the whole-file parse: a 100 MB EMF is unusual; refuse bigger.
      MAX_INPUT_BYTES = 200 * 1024 * 1024

      def variable_array_sane?(type_id, n_size, head, payload)
        sized_arrays_sane?(type_id, n_size, head, payload) &&
          ext_text_out_sane?(type_id, n_size, head, payload)
      end

      def sized_arrays_sane?(type_id, n_size, head, payload)
        spec = VARIABLE_ARRAY_RECORDS[type_id]
        return true unless spec

        full = head + payload
        count_width = spec.fetch(:count_width, 4)
        return true if full.bytesize < spec[:count_offset] + count_width

        count = full.byteslice(spec[:count_offset], count_width).unpack1(count_width == 2 ? "v" : "V")
        return false if count > MAX_SANE_ARRAY_LENGTH

        # For single-array records, element_size is the per-entry size.
        # For multi-array records, the first array (aPolyCounts) entries
        # are always uint32 (4 bytes); element_size applies only to the
        # second array (aptl/apts).
        first_array_entry_size = spec[:count2_offset] ? 4 : spec[:element_size]
        bytes_needed = spec[:count_offset] + count_width + (count * first_array_entry_size)
        return false if bytes_needed > n_size

        # Multi-array records also need to validate the second count.
        return true unless spec[:count2_offset]

        count2 = read_uint32(full, spec[:count2_offset])
        return false if count2 > MAX_SANE_ARRAY_LENGTH

        bytes_needed + (count2 * spec[:element_size]) <= n_size
      end

      ETO_NO_RECT = 0x100
      ETO_PDY = 0x2000
      EXT_TEXT_OUT_CHAR_WIDTH = {
        Binary::TypeCodes::EXTTEXTOUTA => 1,
        Binary::TypeCodes::EXTTEXTOUTW => 2
      }.freeze

      # Mirrors the native decoder: the string and Dx spans implied by nChars
      # must lie inside the record, after the fixed fields, and not overlap.
      def ext_text_out_sane?(type_id, n_size, head, payload)
        width = EXT_TEXT_OUT_CHAR_WIDTH[type_id]
        return true unless width

        spans, fixed = ext_text_out_spans(head + payload, width)
        return false unless spans

        spans.all? { |off, len, align| span_inside?(off, len, align, fixed, n_size) } &&
          (spans.size < 2 || !spans_overlap?(*spans))
      end

      def ext_text_out_spans(full, width)
        return if full.bytesize < 60

        count, off_string, options = full.byteslice(44, 12).unpack("V3")
        dx_at = options.anybits?(ETO_NO_RECT) ? 56 : 72
        return if full.bytesize < dx_at + 4

        off_dx = read_uint32(full, dx_at)
        dx_entry = options.anybits?(ETO_PDY) ? 8 : 4
        string = [off_string, count * width, width] unless off_string.zero? && count.zero?
        dx = [off_dx, count * dx_entry, 4] unless off_dx.zero?
        [[string, dx].compact, dx_at + 4]
      end

      def span_inside?(off, len, align, fixed, n_size)
        (off % align).zero? && off >= fixed && off + len <= n_size
      end

      def spans_overlap?(first, second)
        first[0] < second[0] + second[1] && second[0] < first[0] + first[1]
      end

      def read_uint32(bytes, offset)
        bytes.getbyte(offset) |
          (bytes.getbyte(offset + 1) << 8) |
          (bytes.getbyte(offset + 2) << 16) |
          (bytes.getbyte(offset + 3) << 24)
      end

      def read_record(io, offset, errors)
        head = io.read(8)
        return nil if head.nil? || head.empty?

        type_id, n_size = head.unpack("VV")
        if n_size < 8
          errors << ParseError.new(offset: offset, record_code: type_id,
                                   message: "record nSize #{n_size} < 8 bytes (offset #{offset})")
          return nil
        end

        payload = io.read(n_size - 8)
        if payload.nil? || payload.bytesize < n_size - 8
          errors << ParseError.new(offset: offset, record_code: type_id,
                                   message: "truncated record at offset #{offset} (claimed #{n_size}, got #{payload&.bytesize || 0})")
          return nil
        end

        unless variable_array_sane?(type_id, n_size, head, payload)
          errors << ParseError.new(
            offset: offset, record_code: type_id,
            message: "variable-array record at offset #{offset} declares " \
                     "more entries than nSize allows; preserving as Raw"
          )
          return [build_raw(head, payload), "".b]
        end

        record_bytes = head + payload
        read_typed(type_id, n_size, record_bytes)
      rescue StandardError => e
        errors << ParseError.new(offset: offset, record_code: type_id,
                                 message: "#{e.class}: #{e.message}")
        [build_raw(head, payload), "".b]
      end

      def read_typed(type_id, n_size, record_bytes)
        filler = Emf::Emr::Binary::FastFill.for(type_id)
        return filler.call(record_bytes) if filler && n_size >= filler.size

        wire = Emf::Emr::Binary::Records.lookup(type_id).read(record_bytes)
        [wire, Model::Emr::Records::WireAdapter.suffix_of(record_bytes, wire)]
      end

      def build_raw(head, payload)
        Emf::Emr::Binary::Records::Raw.read(head + (payload || +""))
      end

      EMF_PLUS_IDENTIFIER = 0x2B464D45 # "EMF+" little-endian

      def extract_emf_plus(comment_wire)
        return +"" unless comment_wire.cb_data&.>= 4

        identifier = comment_wire.data.getbyte(0) |
                     (comment_wire.data.getbyte(1) << 8) |
                     (comment_wire.data.getbyte(2) << 16) |
                     (comment_wire.data.getbyte(3) << 24)
        return +"" unless identifier == EMF_PLUS_IDENTIFIER

        # Payload after the 4-byte identifier is the EMF+ record(s).
        comment_wire.data.bytes[4..].pack("C*")
      end
    end
  end
end
