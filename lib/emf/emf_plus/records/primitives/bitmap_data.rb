# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/palette"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBitmapData (2.2.2.3). The parent EmfPlusBitmap says whether
        # its PixelFormat has the I flag, which makes Colors mandatory.
        class BitmapData < BinData::Record
          endian :little
          mandatory_parameter :indexed
          palette :colors, onlyif: :indexed
          rest :pixel_data
        end
      end
    end
  end
end
