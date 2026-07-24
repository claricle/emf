# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class PolyPolyline16 < Emf::Emr::Binary::WithBounds
          uint32 :n_polys
          uint32 :c_pts_total
          array :a_poly_counts, type: :uint32le, initial_length: :n_polys
          array :apts, type: :point_s, initial_length: :c_pts_total
        end
      end
    end
  end
end
