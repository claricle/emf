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
        data = bytes.b.freeze
        pos = io.pos

        records = []
        errors = []
        emf_plus_bytes = +""
        trailing = +""

        while pos < data.bytesize
          offset = pos
          if (source = filled_record_at(data, offset))
            records << Model::Emr::Records::WireAdapter.lazy(source: source, offset: offset)
            pos = offset + source.length
            next
          end

          wire, suffix = read_record_at(data, offset, errors)
          if wire.nil?
            trailing << bytes.byteslice(offset..)
            break
          end

          pos = offset + data.unpack1("V", offset: offset + 4)

          records << Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset, suffix: suffix)
          emf_plus_bytes << comment_emf_plus(wire)

          if wire.is_a?(Emf::Emr::Binary::Records::Eof)
            trailing << data.byteslice(pos..) if pos < data.bytesize
            break
          end
        end

        metafile(header, records, errors, emf_plus_bytes, trailing)
      end

      def metafile(header, records, errors, emf_plus_bytes, trailing)
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
      rescue IOError
        raise FormatError, "EMF header nSize #{n_size} cannot hold its fields"
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

      REGION_DATA_OFFSETS = { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 }.freeze

      def variable_array_sane?(type_id, n_size, record_bytes)
        region_data_sane?(type_id, n_size, record_bytes) &&
          sized_arrays_sane?(type_id, n_size, record_bytes) &&
          ext_text_out_sane?(type_id, n_size, record_bytes)
      end

      def region_data_sane?(type_id, n_size, bytes)
        data_offset = REGION_DATA_OFFSETS[type_id]
        return true unless data_offset

        length_offset = type_id == 75 ? 8 : 24
        return false if bytes.bytesize < length_offset + 4

        length = read_uint32(bytes, length_offset)
        length <= n_size - data_offset
      end

      def sized_arrays_sane?(type_id, n_size, full)
        spec = VARIABLE_ARRAY_RECORDS[type_id]
        return true unless spec

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

      # Types whose declared counts or spans are checked against nSize.
      CHECKED_TYPES = [REGION_DATA_OFFSETS, VARIABLE_ARRAY_RECORDS, EXT_TEXT_OUT_CHAR_WIDTH]
                      .flat_map(&:keys).to_h { |type_id| [type_id, true] }.freeze

      # Mirrors the native decoder: the string and Dx spans implied by nChars
      # must lie inside the record, after the fixed fields, and not overlap.
      def ext_text_out_sane?(type_id, n_size, full)
        width = EXT_TEXT_OUT_CHAR_WIDTH[type_id]
        return true unless width

        spans, fixed = ext_text_out_spans(full, width)
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

      def short_header?(available, offset, errors)
        return false if available >= 8

        errors << ParseError.new(offset: offset, record_code: nil,
                                 message: "truncated record header at offset #{offset} (#{available} bytes)")
        true
      end

      # Reads the record at `offset` of the stream and advances past it.
      def read_record(io, offset, errors)
        data = io.string.b
        result = read_record_at(data, offset, errors)
        io.seek(offset + data.unpack1("V", offset: offset + 4)) if result
        result
      end

      # The byte-backed source of the fixed-layout or point-array record at
      # `offset` of the frozen binary `data`, or nil when the record needs
      # `read_record_at` (any other type, a short or truncated span, a count
      # that overruns its record, or an error to report). The wire is made
      # only when asked for, from the same filler `read_typed` uses.
      def filled_record_at(data, offset)
        return if data.bytesize - offset < 8

        type_id = data.unpack1("V", offset: offset)
        n_size = data.unpack1("V", offset: offset + 4)
        return if n_size < 8 || data.bytesize - offset < n_size

        source = Emr::FilledRecord.for(type_id, offset, n_size, data)
        return unless source
        return source unless CHECKED_TYPES.key?(type_id)

        source if variable_array_sane?(type_id, n_size, data.byteslice(offset, n_size))
      end

      # The record starting at `offset` of the binary `data` as [wire, suffix],
      # or nil when none can be read there (the caller keeps the rest as
      # trailing bytes).
      def read_record_at(data, offset, errors)
        available = data.bytesize - offset
        return nil if available.zero? || short_header?(available, offset, errors)

        type_id = data.unpack1("V", offset: offset)
        n_size = data.unpack1("V", offset: offset + 4)
        if n_size < 8
          errors << ParseError.new(offset: offset, record_code: type_id,
                                   message: "record nSize #{n_size} < 8 bytes (offset #{offset})")
          return nil
        end

        if available < n_size
          errors << ParseError.new(offset: offset, record_code: type_id,
                                   message: "truncated record at offset #{offset} (claimed #{n_size}, got #{available - 8})")
          return nil
        end

        record_bytes = data.byteslice(offset, n_size) if CHECKED_TYPES.key?(type_id)
        unless record_bytes.nil? || variable_array_sane?(type_id, n_size, record_bytes)
          errors << ParseError.new(
            offset: offset, record_code: type_id,
            message: "variable-array record at offset #{offset} declares " \
                     "more entries than nSize allows; preserving as Raw"
          )
          return [build_raw(record_bytes), "".b]
        end

        read_typed(type_id, n_size, data, offset)
      rescue StandardError => e
        errors << ParseError.new(offset: offset, record_code: type_id,
                                 message: "#{e.class}: #{e.message}")
        [build_raw(record_bytes || data.byteslice(offset, n_size)), "".b]
      end

      def read_typed(type_id, n_size, data, offset)
        filler = Emf::Emr::Binary::FastFill.for(type_id) || Emf::Emr::Binary::FastFill.for_points(type_id) ||
                 Emf::Emr::Binary::FastFill.for_text(type_id)
        if filler && n_size >= filler.size
          filled = filler.call_at(data, offset, n_size)
          return filled if filled
        end

        record_bytes = data.byteslice(offset, n_size)
        wire = Emf::Emr::Binary::Records.lookup(type_id).read(record_bytes)
        [wire, Model::Emr::Records::WireAdapter.suffix_of(record_bytes, wire)]
      end

      def build_raw(record_bytes)
        Emf::Emr::Binary::Records::Raw.read(record_bytes)
      end

      EMF_PLUS_IDENTIFIER = 0x2B464D45 # "EMF+" little-endian

      def comment_emf_plus(wire)
        wire.is_a?(Emf::Emr::Binary::Records::Comment) ? extract_emf_plus(wire) : ""
      end

      def extract_emf_plus(comment_wire)
        data = comment_wire.data.to_s.b
        # cbData can claim more bytes than the record holds; read only what is there.
        return +"" unless comment_wire.cb_data&.>=(4) && data.bytesize >= 4
        return +"" unless data.unpack1("V") == EMF_PLUS_IDENTIFIER

        # Payload after the 4-byte identifier is the EMF+ record(s).
        data.byteslice(4..)
      end
    end
  end
end
