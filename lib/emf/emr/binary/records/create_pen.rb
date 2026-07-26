# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_CREATEPEN: iType, nSize, ihPen, LOGPEN{uint32 pen_style, uint32 width, ColorRef color}
        class CreatePen < Emf::Emr::Binary::Record
          uint32 :ih_pen
          uint32 :pen_style
          point_l :width
          color_ref :color
        end
      end
    end
  end
end
