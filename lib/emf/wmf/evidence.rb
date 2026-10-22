# frozen_string_literal: true

module Emf
  module Wmf
    # Neutral evidence for a WMF input the parser rejected. Both backends choose the failing check (the Ruby
    # parser by its own raise, the native backend by its first-rejection reason) and the record offset; the
    # declared and actual values are then read from the input bytes the same way for both.
    #
    # REASONS maps the stable rejection reason (codec * 100 + n, never renumbered) to its check name and the
    # message text the contract raises (`%d` stands for one number; record texts are wrapped as
    # "WMF <text> at offset <offset>").
    module Evidence
      REASONS = {
        101 => [:input_too_large, "WMF input too large"],
        201 => [:placeable_truncated, "truncated WMF placeable header"],
        202 => [:placeable_reserved_nonzero, "WMF placeable reserved field must be zero"],
        203 => [:placeable_checksum_mismatch, "WMF placeable checksum mismatch"],
        301 => [:header_truncated, "truncated WMF standard header"],
        302 => [:header_type_invalid, "invalid WMF Type"],
        303 => [:header_size_invalid, "invalid WMF HeaderSize"],
        304 => [:header_version_invalid, "invalid WMF Version"],
        305 => [:header_file_size_invalid, "invalid WMF file Size"],
        306 => [:placeable_handle_nonzero, "WMF on-disk placeable handle must be zero"],
        1801 => [:max_record_mismatch, "WMF MaxRecord does not match largest record"],
        401 => [:record_limit_exceeded, "record limit exceeded"],
        402 => [:record_header_truncated, "truncated record header"],
        403 => [:record_length_invalid, "invalid record length %d"],
        404 => [:data_after_eof, "data after EOF inside declared WMF Size"],
        405 => [:eof_missing, "missing EOF record"],
        406 => [:eof_length_invalid, "invalid EOF length"],
        501 => [:fixed_record_length_invalid, "invalid fixed record length"],
        601 => [:state_record_length_invalid, "invalid state record length"],
        701 => [:font_record_length_invalid, "invalid font record length"],
        801 => [:object_record_length_invalid, "invalid object record length"],
        901 => [:point_count_missing, "missing point array count"],
        902 => [:polygon_counts_truncated, "truncated polygon counts"],
        903 => [:point_count_invalid, "invalid point count"],
        904 => [:point_array_length_mismatch, "point array length mismatch"],
        1001 => [:text_record_truncated, "truncated text record"],
        1002 => [:text_rectangle_truncated, "truncated text rectangle"],
        1003 => [:text_length_negative, "negative text length"],
        1004 => [:text_string_truncated, "truncated text string"],
        1005 => [:text_spacing_truncated, "truncated text spacing array"],
        1101 => [:palette_prefix_truncated, "truncated palette prefix"],
        1102 => [:palette_entries_truncated, "truncated palette entries"],
        1201 => [:region_prefix_truncated, "truncated region/clipping prefix"],
        1202 => [:region_header_truncated, "truncated region header"],
        1203 => [:region_header_invalid, "invalid region header"],
        1204 => [:region_scan_truncated, "truncated region scan"],
        1205 => [:region_scan_invalid, "invalid region scan"],
        1206 => [:region_scan_size_invalid, "invalid region scan size or maximum"],
        1301 => [:pattern_brush_prefix_truncated, "truncated pattern brush prefix"],
        1302 => [:pattern_brush_extent_invalid, "invalid pattern brush extent"],
        1303 => [:dib_brush_prefix_truncated, "truncated DIB brush prefix"],
        1304 => [:dib_brush_color_usage_invalid, "invalid DIB brush color usage"],
        1401 => [:bitmap_prefix_truncated, "truncated bitmap transfer prefix"],
        1402 => [:bitmap_source_empty, "empty bitmap transfer source"],
        1501 => [:geometry_prefix_truncated, "truncated geometry prefix"],
        1502 => [:flood_fill_mode_invalid, "invalid extended flood fill mode"],
        1601 => [:restore_dc_prefix_truncated, "truncated RestoreDc prefix"],
        1602 => [:escape_prefix_truncated, "truncated Escape prefix"],
        1603 => [:escape_data_truncated, "truncated Escape data or padding"],
        1701 => [:object_table_full, "object table capacity exceeded"],
        1702 => [:object_reference_invalid, "invalid object reference %d"],
        1703 => [:object_reference_not_palette, "object reference %d is not a palette"],
        1704 => [:object_reference_not_region, "object reference %d is not a region"],
        1705 => [:region_reference_invalid, "invalid region reference %d"],
        1706 => [:brush_reference_invalid, "invalid brush reference %d"],
        1707 => [:object_reference_not_brush, "object reference %d is not a brush"]
      }.freeze

      INPUT_REASONS = [101, 201, 202, 203, 301, 302, 303, 304, 305, 306, 1801].freeze
      REFERENCE_REASONS = (1702..1707).to_a.freeze
      WORD_BYTES = 2

      MESSAGE_PATTERNS = REASONS.to_h do |reason, (_check, text)|
        pattern = Regexp.escape(text).sub("%d", "(\\d+)")
        [reason, INPUT_REASONS.include?(reason) ? /\A#{pattern}\z/ : /\AWMF #{pattern} at offset (\d+)\z/]
      end.freeze
      private_constant :MESSAGE_PATTERNS

      module_function

      # Evidence for a FormatError or ParseError raised by the Ruby parser, or nil when it is not a contract rejection.
      def from_error(error, bytes)
        reason, pattern = MESSAGE_PATTERNS.find { |_code, candidate| candidate.match?(error.message) }
        return unless reason

        detail = REFERENCE_REASONS.include?(reason) ? pattern.match(error.message)[1].to_i : nil
        build(reason, bytes, error.respond_to?(:offset) ? error.offset : nil, detail)
      end

      # The one evidence builder both backends use once they know the reason and (for record failures) the offset.
      def build(reason, bytes, offset, detail = nil)
        check = REASONS.fetch(reason).first
        values = INPUT_REASONS.include?(reason) ? input_values(reason, bytes) : record_values(reason, bytes, offset, detail)
        offset, declared, actual = values
        ParseEvidence.new(check: check, offset: offset, declared: declared, actual: actual)
      end

      def input_values(reason, bytes)
        view = View.new(bytes)
        case reason
        when 101 then [0, Binary::MAX_INPUT_BYTES, bytes.bytesize]
        when 201 then [0, Binary::PLACEABLE_BYTES, bytes.bytesize]
        when 202 then [16, 0, bytes.unpack1("V", offset: 16)]
        when 203 then [20, bytes.unpack1("v", offset: 20), Binary.checksum(bytes.byteslice(0, 20))]
        when 306 then [4, bytes.unpack1("v", offset: 4), 0]
        else header_values(reason, bytes, view)
        end
      end

      def header_values(reason, bytes, view)
        case reason
        when 301 then [view.start, Binary::HEADER_BYTES, bytes.bytesize - view.start]
        when 302 then [view.start, view.u16(0), nil]
        when 303 then [view.start + 2, view.u16(2), 9]
        when 304 then [view.start + 4, view.u16(4), nil]
        when 305 then [view.start + 6, view.u32(6), (bytes.bytesize - view.start) / WORD_BYTES]
        else [view.start + 12, view.u32(12), view.largest_record_words]
        end
      end

      def record_values(reason, bytes, offset, detail)
        view = View.new(bytes)
        words = view.u32_at(offset)
        declared, actual = record_pair(reason, view, offset, words, detail)
        [offset, declared, actual]
      end

      def record_pair(reason, view, offset, words, detail)
        case reason
        when 401 then [Binary::MAX_RECORDS, Binary::MAX_RECORDS]
        when 402 then [6, view.limit - offset]
        when 403 then [words, (view.limit - offset) / WORD_BYTES]
        when 404, 405 then [view.limit, offset]
        when 406 then [words, 3]
        when 501, 601, 701, 801 then [words, view.required_words(reason, offset)]
        when 1701 then [view.u16(10), nil]
        when *REFERENCE_REASONS then [detail, view.u16(10)]
        else [words, nil]
        end
      end

      # Reads fields of an input that already passed the checks before the one being described.
      class View
        def initialize(bytes)
          @bytes = bytes
          @start = bytes.bytesize >= 4 && bytes.unpack1("V") == Binary::PLACEABLE_KEY ? Binary::PLACEABLE_BYTES : 0
        end

        attr_reader :start

        def u16(offset)
          @bytes.unpack1("v", offset: @start + offset)
        end

        def u32(offset)
          @bytes.unpack1("V", offset: @start + offset)
        end

        def u32_at(offset)
          @bytes.unpack1("V", offset: offset) if offset && offset + 4 <= @bytes.bytesize
        end

        def limit
          @start + (u32(6) * WORD_BYTES)
        end

        def largest_record_words
          offset = @start + Binary::HEADER_BYTES
          largest = 0
          while offset + 4 <= limit && (words = u32_at(offset)).positive?
            largest = [largest, words].max
            offset += words * WORD_BYTES
          end
          largest
        end

        def required_words(reason, offset)
          function = @bytes.unpack1("v", offset: offset + 4) & 0xFF
          record_class = { 501 => Binary::FIXED_RECORDS, 601 => Binary::STATE_RECORDS, 701 => nil, 801 => Binary::OBJECT_RECORDS }
          record_class = reason == 701 ? Model::Wmf::Records::CreateFontIndirect : record_class.fetch(reason).fetch(function)
          reason == 501 ? 3 + record_class::WIRE_FIELDS.length : 3 + (record_class::PAYLOAD_BYTES / WORD_BYTES)
        end
      end
    end
  end
end
