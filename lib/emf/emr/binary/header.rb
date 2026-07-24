# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      # EMF metafile header record. The fixed portion is 88 bytes ending at
      # szlMillimeters. The remaining fields (cbPixelFormat, offPixelFormat,
      # bOpenGL, szlMicrometers) are optional — present only when nSize is
      # 100 or 108. An optional UTF-16LE description string follows at
      # offDescription for nDescription Unicode chars.
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
        # Win95-and-later fields (absent in 88-byte headers).
        uint32 :cb_pixel_format, onlyif: -> { n_size > 88 }       # PixelFormatDescriptor size, 0 if none
        uint32 :off_pixel_format, onlyif: -> { n_size > 88 }      # offset to PixelFormatDescriptor
        uint32 :b_open_gl, onlyif: -> { n_size > 88 }             # nonzero if OpenGL records present
        # Win98-and-later field (absent in 100-byte headers).
        size_l :szl_micrometers, onlyif: -> { n_size > 100 } # device size in micrometers
        # Capture any trailing bytes beyond the declared optional fields.
        rest :trailing
      end
    end
  end
end
