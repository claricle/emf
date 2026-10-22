# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/bounded_array"
require "emf/emf_plus/records/primitives/character_range"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusStringFormatData (2.2.2.44). Both arrays are sized by the
        # parent EmfPlusStringFormat's TabStopCount and RangeCount.
        class StringFormatData < Body
          endian :little
          mandatory_parameters :tab_stop_count, :range_count
          bounded_array :tab_stops, type: :float32_le, element_size: 4, initial_length: :tab_stop_count
          bounded_array :char_ranges, type: :character_range, element_size: 8, initial_length: :range_count
        end
      end
    end
  end
end
