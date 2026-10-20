# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusGraphicsVersion (2.2.2.19): 20-bit MetafileSignature (0xDBC01)
        # above a 12-bit GraphicsVersion in one little-endian dword.
        class GraphicsVersion < BinData::Record
          endian :little
          uint32 :raw

          def metafile_signature = raw >> 12
          def graphics_version = raw & 0xFFF
        end
      end
    end
  end
end
