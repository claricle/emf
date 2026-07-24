# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_STRETCHDIBITS per MS-EMF 2.3.1.7. The full layout:
        #   emr
        #   rclBounds (RECTL)
        #   xDest, yDest (int32)
        #   xSrc, ySrc (int32)
        #   cxSrc, cySrc (int32)
        #   offBmiSrc, cbBmiSrc (uint32) — offset/size of BITMAPINFO from record start
        #   offBitsSrc, cbBitsSrc (uint32) — offset/size of pixel array from record start
        #   iUsageSrc (uint32) — DIBColors
        #   dwRop (uint32) — ternary raster op
        #   cxDest, cyDest (int32)
        #   [trailing BITMAPINFO + pixel array]
        class StretchDIBits < Emf::Emr::Binary::WithBounds
          int32 :x_dest
          int32 :y_dest
          int32 :x_src
          int32 :y_src
          int32 :cx_src
          int32 :cy_src
          uint32 :off_bmi_src
          uint32 :cb_bmi_src
          uint32 :off_bits_src
          uint32 :cb_bits_src
          uint32 :i_usage_src
          uint32 :dw_rop
          int32 :cx_dest
          int32 :cy_dest
          rest :trailing
        end
      end
    end
  end
end
