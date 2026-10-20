# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusCompressedImage (2.2.2.10).
        class CompressedImage < BinData::Record
          endian :little
          rest :compressed_image_data
        end
      end
    end
  end
end
