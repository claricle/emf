# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusFont (2.2.1.3).
      class Font < Typed
        FIXED_SIZE = 24
        LENGTH_OFFSET = 20

        class FontBody < BinData::Record
          endian :little
          graphics_version :version
          float :em_size
          uint32 :size_unit
          int32 :font_style_flags
          uint32 :reserved
          uint32 :char_count
          string :family_name, read_length: -> { char_count * 2 }
        end
        BODY = FontBody

        def em_size = body.em_size
        def size_unit = body.size_unit
        def style_flags = body.font_style_flags

        def family_name
          body.family_name.to_s.dup.force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end

        private

        def check_bounds(data, logical)
          return if data.bytesize < FIXED_SIZE

          length = data.byteslice(LENGTH_OFFSET, 4).unpack1("V")
          require_room(data, logical, FIXED_SIZE + (length * 2), "FamilyName of #{length} characters")
        end
      end
    end
  end
end
