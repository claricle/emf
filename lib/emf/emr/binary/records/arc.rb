# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_ARC: emr + rclBox + ptlStart + ptlEnd (no rclBounds).
        class Arc < Emf::Emr::Binary::Record
          rectl :rcl_box
          point_l :ptl_start
          point_l :ptl_end
        end
      end
    end
  end
end
