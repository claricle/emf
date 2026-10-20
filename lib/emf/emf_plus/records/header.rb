# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusHeader (2.3.3.3). Record Flags bit D marks EMF+ Dual; the V bit
      # of EmfPlusFlags marks a video reference device.
      class Header < Base
        TYPE = 0x4001
        GRAPHICS_SIGNATURE = 0xDBC01
        DUAL_FLAG = 0x0001
        VIDEO_FLAG = 0x00000001

        class HeaderBody < Body
          endian :little
          uint32 :graphics_version
          uint32 :emf_plus_flags
          uint32 :logical_dpi_x
          uint32 :logical_dpi_y
        end
        BODY = HeaderBody

        def flag_fields = { dual: DUAL_FLAG }

        def dual? = flags.anybits?(DUAL_FLAG)
        def video? = body.emf_plus_flags.anybits?(VIDEO_FLAG)
        def graphics_signature = body.graphics_version >> 12
        def graphics_version = body.graphics_version & 0xFFF
        def valid_signature? = graphics_signature == GRAPHICS_SIGNATURE
        def logical_dpi_x = body.logical_dpi_x
        def logical_dpi_y = body.logical_dpi_y
      end
    end
  end
end
