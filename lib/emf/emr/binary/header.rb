# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      # EMF metafile header record. The fixed portion is 100 bytes ending at
      # szlMicrometers. An optional UTF-16LE description string follows at
      # offset offDescription for nDescription Unicode chars. nSize declares
      # the total record size (including the description string).
      class Header < BinData::Record
        endian :little
        uint32 :i_type                # 1
        uint32 :n_size                # total record size in bytes
        rectl :rcl_bounds             # bounding rectangle in device units
        rectl :rcl_frame              # bounding rectangle in 0.01 mm units
        uint32 :d_signature           # 0x464D4520 (" EMF")
        uint32 :n_version             # 0x00010000 typical
        uint32 :n_bytes               # metafile size in bytes
        uint32 :n_records             # total record count
        uint16 :n_handles             # graphics object count + 1
        uint16 :s_reserved            # must be 0
        uint32 :n_description         # UTF-16LE char count of description (0 if none)
        uint32 :off_description       # byte offset to description from record start
        uint32 :n_pal_entries         # palette entries (used by EMR_EOF)
        size_l :szl_device            # reference device size in pixels
        size_l :szl_millimeters       # reference device size in 0.01 mm
        uint32 :cb_pixel_format       # PixelFormatDescriptor size, 0 if none
        uint32 :off_pixel_format      # offset to PixelFormatDescriptor
        uint32 :b_open_gl             # nonzero if OpenGL records present
        size_l :szl_micrometers       # device size in micrometers (EMF+ variant)
        rest :trailing                # captures any extension bytes beyond the fixed header
      end
    end
  end
end
