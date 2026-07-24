# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class StretchDIBits < Emf::Emr::Binary::WithBounds
          uint32 :x_dest
          uint32 :y_dest
          uint32 :x_src
          uint32 :y_src
          uint32 :cx_src
          uint32 :cy_src
          rest :body
        end
      end
    end
  end
end
