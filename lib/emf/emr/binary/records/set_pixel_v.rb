# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_SETPIXELV: emr + ptlPixel (POINTL) + crColor (COLORREF).
        class SetPixelV < Emf::Emr::Binary::Record
          point_l :ptl_pixel
          color_ref :cr_color
        end
      end
    end
  end
end
