# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTTEXTOUTW per MS-EMF 2.3.8.2. The layout after the header:
        #   rclBounds      (RECTL, in WithBounds)
        #   iGraphicsMode  (uint32)
        #   exScale        (float)
        #   eyScale        (float)
        #   ref_WmfRect16  (RECT_S: 4 int16 = 8 bytes)
        #   nChars         (uint32)
        #   offString      (uint32) — byte offset from record start to string
        #   fOptions       (uint32) — ExtTextOutOptions flags
        #   ref_WmfRect16_2 (RECT_S)
        #   offDx          (uint32) — byte offset to Dx array
        #   ...string (UTF-16LE, nChars chars)...
        #   ...Dx array (uint32 per char)...
        class ExtTextOutW < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          int16 :wmf_rect_left
          int16 :wmf_rect_top
          int16 :wmf_rect_right
          int16 :wmf_rect_bottom
          uint32 :n_chars
          uint32 :off_string
          uint32 :f_options
          int16 :wmf_rect2_left
          int16 :wmf_rect2_top
          int16 :wmf_rect2_right
          int16 :wmf_rect2_bottom
          uint32 :off_dx
          rest :trailing
        end
      end
    end
  end
end
