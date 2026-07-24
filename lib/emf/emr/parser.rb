# frozen_string_literal: true

require "stringio"

module Emf
  module Emr
    module Parser
      module_function

      def call(bytes)
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
          wire = read_record(io, offset, errors)
          break if wire.nil?

          records << Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset)
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
        Binary::TypeCodes::POLYDRAW => { count_offset: 24, element_size: 9 }, # 8 + 1 byte type
        Binary::TypeCodes::POLYDRAW16 => { count_offset: 24, element_size: 5 }
      }.freeze

      MAX_SANE_ARRAY_LENGTH = 1_000_000

      def variable_array_sane?(type_id, n_size, head, payload)
        spec = VARIABLE_ARRAY_RECORDS[type_id]
        return true unless spec

        full = head + payload
        return true if full.bytesize < spec[:count_offset] + 4

        offset = spec[:count_offset]
        count = full.getbyte(offset) |
                (full.getbyte(offset + 1) << 8) |
                (full.getbyte(offset + 2) << 16) |
                (full.getbyte(offset + 3) << 24)
        bytes_needed = spec[:count_offset] + 4 + (count * spec[:element_size])
        count <= MAX_SANE_ARRAY_LENGTH && bytes_needed <= n_size
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
          return build_raw(head, payload)
        end

        wire_class = Emf::Emr::Binary::Records.lookup(type_id)
        wire_class.read(head + payload)
      rescue StandardError => e
        errors << ParseError.new(offset: offset, record_code: type_id,
                                 message: "#{e.class}: #{e.message}")
        build_raw(head, payload)
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
