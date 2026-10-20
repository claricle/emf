# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/bitmap_data"
require "emf/emf_plus/records/primitives/compressed_image"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBitmap (2.2.2.2). BitmapDataType 0 is pixel data, 1 is a
        # compressed image; any other value keeps its bytes in unrecognized_data.
        class Bitmap < BinData::Record
          PIXEL = 0
          COMPRESSED = 1
          INDEXED_FLAG = 0x10000

          endian :little
          int32 :width
          int32 :height
          int32 :stride
          uint32 :pixel_format
          uint32 :bitmap_type
          bitmap_data :bitmap_data, onlyif: -> { bitmap_type == PIXEL },
                                    indexed: -> { pixel_format.anybits?(INDEXED_FLAG) }
          compressed_image :compressed_image, onlyif: -> { bitmap_type == COMPRESSED }
          rest :unrecognized_data, onlyif: -> { ![PIXEL, COMPRESSED].include?(bitmap_type) }
        end
      end
    end
  end
end
