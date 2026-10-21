# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"
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
          array :tab_stops, type: :float32_le, initial_length: :tab_stop_count
          array :char_ranges, type: :character_range, initial_length: :range_count
        end
      end
    end
  end
end
