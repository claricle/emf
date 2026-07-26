# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMRSTRETCHBLT (MS-EMF 2.3.1.6).
        # Layout: emr, rclBounds, Dest, cDest, dwRop, Src, xformSrc (24
        # bytes), crBkColorSrc, iUsageSrc, offBmiSrc, cbBmiSrc,
        # offBitsSrc, cbBitsSrc, cSrc, then trailing BMI/bitmap data.
        # Only the fields the emfsvg renderer needs are declared; the
        # 32-byte xform+bgcolor+usage blob in the middle is skipped via
        # a fixed-size :bytes buffer (NOT :rest, which would consume the
        # whole tail).
        class StretchBlt < Emf::Emr::Binary::WithBounds
          int32le :x_dest
          int32le :y_dest
          int32le :cx_dest
          int32le :cy_dest
          uint32le :dw_rop
          int32le :x_src
          int32le :y_src
          # xformSrc (24 bytes) + crBkColorSrc (4) + iUsageSrc (4) = 32 bytes
          string :xform_usage_etc, length: 32, read_trim_padding: true
          uint32le :off_bmi_src
          uint32le :cb_bmi_src
          uint32le :off_bits_src
          uint32le :cb_bits_src
          int32le :cx_src
          int32le :cy_src
          rest :body
        end
      end
    end
  end
end
