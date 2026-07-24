# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class Polyline16 < Emf::Emr::Binary::WithBounds
          uint32 :cpts
          array :apts, type: :point_s, initial_length: :cpts
        end
      end
    end
  end
end
