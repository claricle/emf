# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class GradientFill < Emf::Emr::Binary::WithBounds
          uint32 :n_ver
          uint32 :n_tri
          uint32 :ul_mode
          rest :body
        end
      end
    end
  end
end
