# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: parses only the leading fields; full ExtTextOutW layout per
        # MS-EMF 2.3.8.2 lands with TODO 10.
        class ExtTextOutW < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          rest :body
        end
      end
    end
  end
end
