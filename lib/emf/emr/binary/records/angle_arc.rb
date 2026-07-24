# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class AngleArc < Emf::Emr::Binary::Record
          point_l :ptl_center
          uint32 :n_radius
          float :start_angle
          float :sweep_angle
        end
      end
    end
  end
end
