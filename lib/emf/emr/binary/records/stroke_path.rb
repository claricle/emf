# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_STROKE_PATH: emr + rclBounds per MS-EMF 2.3.5.9/2.3.5.38/2.3.5.39.
        class StrokePath < Emf::Emr::Binary::WithBounds
        end
      end
    end
  end
end
