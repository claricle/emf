# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class ScaleWindowExtEx < Emf::Emr::Binary::Record
          int32 :x_num
          int32 :x_denom
          int32 :y_num
          int32 :y_denom
        end
      end
    end
  end
end
