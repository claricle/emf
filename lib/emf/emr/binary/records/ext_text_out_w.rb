# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTTEXTOUTW per MS-EMF 2.3.8.2. The EMRTEXT struct follows:
        #   emr            (8 bytes, in WithBounds header)
        #   rclBounds      (16 bytes, in WithBounds)
        #   iGraphicsMode  (uint32)
        #   exScale        (float)
        #   eyScale        (float)
        #   --- EMRTEXT starts ---
        #   ptlReference   (POINTL: int32 x, int32 y) — text anchor point
        #   nChars         (uint32)
        #   offString      (uint32) — byte offset from record start
        #   fOptions       (uint32) — ExtTextOutOptions flags
        #   rcl            (RECTL) — clipping rectangle
        #   offDx          (uint32) — byte offset to Dx array
        #   --- EMRTEXT ends ---
        #   ...string (UTF-16LE, nChars chars)...
        #   ...Dx array (uint32 per char)...
        class ExtTextOutW < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          point_l :ptl_reference
          uint32 :n_chars
          uint32 :off_string
          uint32 :f_options
          rectl :rcl
          uint32 :off_dx
          rest :trailing
        end
      end
    end
  end
end
