# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusMetafile (2.2.2.27).
        class Metafile < BinData::Record
          endian :little
          uint32 :metafile_type
          uint32 :metafile_data_size
          string :metafile_data, read_length: :metafile_data_size
        end
      end
    end
  end
end
