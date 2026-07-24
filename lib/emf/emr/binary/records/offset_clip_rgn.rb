# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class OffsetClipRgn < Emf::Emr::Binary::Record
          point_l :ptl_offset
        end
      end
    end
  end
end
