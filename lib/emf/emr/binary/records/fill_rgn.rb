# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/region_data"

module Emf
  module Emr
    module Binary
      module Records
        class FillRgn < Emf::Emr::Binary::WithBounds
          uint32 :cb_rgn_data
          uint32 :ih_brush
          region_data :rgn_data, byte_length: :cb_rgn_data
          rest :body
        end
      end
    end
  end
end
