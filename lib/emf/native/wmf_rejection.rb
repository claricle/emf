# frozen_string_literal: true

module Emf
  module Native
    # Maps the native WMFR answer (codec, reason, offset, function, detail) to the exact error the Ruby contract
    # raises: its class, message, offset and record code. Rust names the first failing phase; this table owns
    # only the wording. Reason codes are codec * 100 + n and are never renumbered.
    module WmfRejection
      Found = Struct.new(:codec, :reason, :offset, :function, :detail)

      # Whole-input failures: FormatError with the message as is. 305 (Size) and 1801 (MaxRecord) are recovered, not
      # rejected, and 404 is retired with them.
      INPUT = {
        101 => "WMF input too large",
        201 => "truncated WMF placeable header",
        202 => "WMF placeable reserved field must be zero",
        203 => "WMF placeable checksum mismatch",
        301 => "truncated WMF standard header",
        302 => "invalid WMF Type",
        303 => "invalid WMF HeaderSize",
        304 => "invalid WMF Version",
        306 => "WMF on-disk placeable handle must be zero"
      }.freeze

      # Record failures: ParseError "WMF <text> at offset <offset>". `%d` takes the numeric detail.
      RECORD = {
        401 => "record limit exceeded", 402 => "truncated record header", 403 => "invalid record length %d",
        405 => "missing EOF record", 406 => "invalid EOF length",
        501 => "invalid fixed record length", 601 => "invalid state record length", 701 => "invalid font record length",
        801 => "invalid object record length",
        901 => "missing point array count", 902 => "truncated polygon counts", 903 => "invalid point count",
        904 => "point array length mismatch",
        1001 => "truncated text record", 1002 => "truncated text rectangle", 1003 => "negative text length",
        1004 => "truncated text string", 1005 => "truncated text spacing array",
        1101 => "truncated palette prefix", 1102 => "truncated palette entries",
        1201 => "truncated region/clipping prefix", 1202 => "truncated region header", 1203 => "invalid region header",
        1204 => "truncated region scan", 1205 => "invalid region scan", 1206 => "invalid region scan size or maximum",
        1301 => "truncated pattern brush prefix", 1302 => "invalid pattern brush extent",
        1303 => "truncated DIB brush prefix", 1304 => "invalid DIB brush color usage",
        1401 => "truncated bitmap transfer prefix", 1402 => "empty bitmap transfer source",
        1501 => "truncated geometry prefix", 1502 => "invalid extended flood fill mode",
        1601 => "truncated RestoreDc prefix", 1602 => "truncated Escape prefix", 1603 => "truncated Escape data or padding",
        1701 => "object table capacity exceeded", 1702 => "invalid object reference %d",
        1703 => "object reference %d is not a palette", 1704 => "object reference %d is not a region",
        1705 => "invalid region reference %d", 1706 => "invalid brush reference %d",
        1707 => "object reference %d is not a brush"
      }.freeze

      LAYOUT = "a4V7Q<2"
      LENGTH = 48

      module_function

      # Returns nil when the contract accepts the input.
      def read(bytes)
        magic, version, present, codec, reason, has_offset, has_function, function, offset, detail =
          bytes.unpack(LAYOUT)
        raise FormatError, "invalid native WMF rejection" unless bytes.bytesize == LENGTH && magic == "WMFR" && version == 1

        return if present.zero?

        Found.new(codec, reason, has_offset == 1 ? offset : nil, has_function == 1 ? function : nil, detail)
      end

      def error(found, input)
        evidence = Wmf::Evidence.build(found.reason, input, found.offset, found.detail)
        return FormatError.new(INPUT.fetch(found.reason)).with_evidence(evidence) if INPUT.key?(found.reason)

        template = RECORD.fetch(found.reason) { raise FormatError, "unknown native WMF rejection #{found.reason}" }
        text = template.sub("%d", found.detail.to_s)
        ParseError.new(offset: found.offset, record_code: found.function, message: "WMF #{text} at offset #{found.offset}")
                  .with_evidence(evidence)
      end
    end
  end
end
