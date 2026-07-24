# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_CREATEBRUSHINDIRECT: iType, nSize, ihBrush, LOGBRUSH32.
        class CreateBrushIndirect < Emf::Emr::Binary::Record
          uint32 :ih_brush
          uint32 :brush_style
          color_ref :color
          uint32 :brush_hatch
        end
      end
    end
  end
end
