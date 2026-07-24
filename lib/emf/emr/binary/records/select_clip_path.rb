# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_SELECTCLIPPATH: emr + rclBounds + RegionMode per MS-EMF 2.3.2.5.
        class SelectClipPath < Emf::Emr::Binary::WithBounds
          uint32 :region_mode
        end
      end
    end
  end
end
