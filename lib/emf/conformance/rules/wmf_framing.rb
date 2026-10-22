# frozen_string_literal: true

# WMF header, placeable header and record-framing rules over the accepted public
# model (MS-WMF 2.2.2 headers, 2.3.2 control records). They read only
# Metafile#header, Metafile#records and the input length; declared record sizes
# are not on the public WMF model, so size rules stay blocked (see manifest).
module Emf
  module Conformance
    module WmfFramingRules
      WMF = %i[wmf].freeze
      PLACEABLE_KEY = 0x9AC6CDD7
      HEADER_WORDS = 9
      PLACEABLE_BYTES = 22
      EOF_FUNCTION = 0

      module_function

      def header_type(context)
        type = context.header.type
        return [] if [1, 2].include?(type)

        [{ message: "WMF header Type is #{type.inspect}, MUST be 1 (memory) or 2 (disk)", offset: header_offset(context) }]
      end

      def header_version(context)
        version = context.header.version
        return [] if [0x0100, 0x0300].include?(version)

        [{ message: format("WMF header Version is 0x%04X, MUST be 0x0100 or 0x0300", version.to_i), offset: header_offset(context) + 4 }]
      end

      def header_size(context)
        words = context.header.size_words.to_i
        found = []
        found << "WMF header Size is #{words} words, less than the #{HEADER_WORDS}-word header" if words < HEADER_WORDS
        if context.byte_length && (words * 2) + header_offset(context) > context.byte_length
          found << "WMF header Size #{words} words runs past the #{context.byte_length}-byte input"
        end
        found.map { |message| { message: message, offset: header_offset(context) + 6 } }
      end

      def header_members(context)
        members = context.header.number_of_members.to_i
        return [] if members.zero?

        [{ message: "WMF header NumberOfMembers is #{members}, SHOULD be 0", offset: header_offset(context) + 16 }]
      end

      # HWmf MUST be 0 only for a metafile on disk (Type 2); an in-memory metafile (Type 1) carries its handle.
      def placeable_handle(context)
        placeable = context.header.placeable
        return [] unless placeable && context.header.type.to_i == 2 && !placeable.handle.to_i.zero?

        [{ message: "WMF placeable HWmf is #{placeable.handle} on a disk metafile (Type 2), MUST be 0", offset: 4 }]
      end

      def placeable_checksum(context)
        placeable = context.header.placeable
        return [] unless placeable

        expected = checksum(placeable)
        return [] if placeable.checksum == expected

        [{ message: format("WMF placeable Checksum is 0x%<actual>04X, the XOR of the preceding ten words is 0x%<expected>04X",
                           actual: placeable.checksum.to_i, expected: expected), offset: 20 }]
      end

      def eof_missing(context)
        last = context.records.last
        return [] if last && last.type_id.to_i == EOF_FUNCTION

        [{ message: "WMF metafile does not end with a META_EOF record", offset: last&.offset, record_index: context.records.size,
           record_type: last&.type_id }]
      end

      def eof_not_last(context)
        context.records.each_with_index.filter_map do |record, index|
          next unless record.type_id.to_i == EOF_FUNCTION && index != context.records.size - 1

          at(record, index, "META_EOF is followed by #{context.records.size - 1 - index} more record(s)")
        end
      end

      def unknown_function(context)
        context.records.each_with_index.filter_map do |record, index|
          next unless record.is_a?(Emf::Model::Wmf::Records::UnknownRecord)

          at(record, index, format("record function 0x%04X is not a specified MS-WMF record type", record.type_id.to_i))
        end
      end

      def trailing_bytes(context)
        extra = context.metafile.trailing.to_s.bytesize
        return [] if extra.zero?

        [{ message: "#{extra} bytes follow the declared WMF Size", offset: context.byte_length && (context.byte_length - extra),
           record_index: context.records.size }]
      end

      def header_offset(context) = context.header.placeable ? PLACEABLE_BYTES : 0

      def checksum(placeable)
        words = [PLACEABLE_KEY & 0xFFFF, PLACEABLE_KEY >> 16, placeable.handle, placeable.left, placeable.top, placeable.right,
                 placeable.bottom, placeable.inch, 0, 0]
        words.map { |word| word.to_i & 0xFFFF }.reduce(0, :^)
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end
    end

    registry = Registry.loading
    [
      ["wmf.header.type", :header_type, "MS-WMF 2.3.2.2 META_HEADER (Type); 2.1.1.18 MetafileType Enumeration", :header_type, nil],
      ["wmf.header.version", :header_version, "MS-WMF 2.3.2.2 META_HEADER (Version); " \
                                              "2.1.1.19 MetafileVersion Enumeration", :header_version, nil],
      ["wmf.header.size", :header_size, "MS-WMF 2.3.2.2 META_HEADER (SizeLow, SizeHigh)", :header_size, nil],
      ["wmf.header.number_of_members", :header_members, "MS-WMF 2.3.2.2 META_HEADER (NumberOfMembers)", :header_members,
       "NumberOfMembers is reserved and no reader consults it", :warning],
      ["wmf.placeable.handle", :placeable_handle, "MS-WMF 2.3.2.3 META_PLACEABLE (HWmf)", :placeable_handle,
       "readers ignore the handle of an in-file placeable header"],
      ["wmf.placeable.checksum", :placeable_checksum, "MS-WMF 2.3.2.3 META_PLACEABLE (Checksum)", :placeable_checksum, nil],
      ["wmf.eof.missing", :eof_missing, "MS-WMF 2.3.2.1 META_EOF", :eof_missing, nil],
      ["wmf.eof.not_last", :eof_not_last, "MS-WMF 2.3.2.1 META_EOF", :eof_not_last, nil],
      ["wmf.record.unknown_function", :unknown_function, "MS-WMF 2.1.1.1 RecordType Enumeration; " \
                                                         "2.3 WMF Records (unknown record types are ignored)", :unknown_function,
       "unspecified functions are skipped by size, so the stream stays readable"],
      ["wmf.eof.trailing_bytes", :trailing_bytes, "MS-WMF 2.3.2.2 META_HEADER (SizeLow, SizeHigh)", :trailing_bytes,
       "bytes after the declared Size are ignored by readers"]
    ].each do |id, method, citation, kind, reason, severity = :error|
      registry.register(id: id, formats: WmfFramingRules::WMF, citation: citation, kind: kind, severity: severity,
                        tolerant_reason: reason) do |context|
        WmfFramingRules.public_send(method, context)
      end
    end
  end
end
