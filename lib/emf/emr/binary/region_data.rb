# frozen_string_literal: true

require "bindata"
require "emf/binary/types"

module Emf
  module Emr
    module Binary
      # MS-EMF 2.2.24: a 32-byte header followed by RectL objects.
      class RegionData < BinData::Record
        mandatory_parameter :byte_length
        endian :little
        uint32 :header_size, initial_value: 32
        uint32 :region_type
        uint32 :count_rects
        uint32 :rgn_size
        rectl :bounds
        array :rectangles, type: :rectl, initial_length: :count_rects
        string :trailing, read_length: -> { [eval_parameter(:byte_length) - 32 - (count_rects * 16), 0].max }
      end
    end
  end
end

BinData::RegisteredClasses.register("region_data", Emf::Emr::Binary::RegionData)
