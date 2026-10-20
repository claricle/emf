# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/language_identifier"
require "emf/emf_plus/records/primitives/string_format_data"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusStringFormat (2.2.1.9).
      class StringFormat < Typed
        FIXED_SIZE = 60
        COUNTS_OFFSET = 52

        class StringFormatBody < BinData::Record
          endian :little
          graphics_version :version
          uint32 :string_format_flags
          language_identifier :language
          uint32 :string_alignment
          uint32 :line_align
          uint32 :digit_substitution
          language_identifier :digit_language
          float :first_tab_offset
          int32 :hotkey_prefix
          float :leading_margin
          float :trailing_margin
          float :tracking
          uint32 :trimming
          int32 :tab_stop_count
          int32 :range_count
          string_format_data :string_format_data, tab_stop_count: -> { tab_stop_count },
                                                  range_count: -> { range_count }
        end
        BODY = StringFormatBody

        def flags = body.string_format_flags
        def tab_stops = body.string_format_data.tab_stops.to_a
        def char_ranges = body.string_format_data.char_ranges.map { |r| [r.first_position, r.range_length] }

        private

        def check_bounds(data, logical)
          return if data.bytesize < FIXED_SIZE

          tab_stops, ranges = data.byteslice(COUNTS_OFFSET, 8).unpack("l<l<")
          fail_parse(logical, "negative count (TabStopCount #{tab_stops}, RangeCount #{ranges})") if tab_stops.negative? || ranges.negative?
          require_room(data, logical, FIXED_SIZE + (tab_stops * 4) + (ranges * 8),
                       "StringFormatData of #{tab_stops} tab stops and #{ranges} ranges")
        end
      end
    end
  end
end
