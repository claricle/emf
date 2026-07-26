# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_ROUNDRECT: emr + rclBox per MS-EMF 2.3.5.
        # No rclBounds.
        class RoundRect < Emf::Emr::Binary::Record
  rectl :rcl_box
  size_l :szl_corner
        end
      end
    end
  end
end
