# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusLanguageIdentifier (2.2.2.23): 6-bit SubLanguageId above a
        # 10-bit PrimaryLanguageId. The containing objects reserve a full
        # dword for it, so the whole dword is kept.
        class LanguageIdentifier < Body
          endian :little
          uint32 :raw

          def primary_language_id = raw & 0x3FF
          def sub_language_id = (raw >> 10) & 0x3F
        end
      end
    end
  end
end
