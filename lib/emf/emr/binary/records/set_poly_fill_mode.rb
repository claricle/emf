# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetPolyFillMode < Emf::Emr::Binary::Record
          uint32 :poly_fill_mode
        end
      end
    end
  end
end
