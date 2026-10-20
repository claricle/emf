# frozen_string_literal: true

require "emf/emf_plus/records/primitives/point_f"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawDriverString (2.3.4.6). The glyph position array always holds
      # GlyphCount elements, as the Size and DataSize formulas require.
      class DrawDriverString < Base
        TYPE = 0x4036
        SOLID_COLOR_FLAG = 0x8000
        OBJECT_ID_MASK = 0x00FF
        CMAP_LOOKUP = 0x00000001

        class DrawDriverStringBody < BinData::Record
          endian :little
          uint32 :brush_id
          uint32 :options_flags
          uint32 :matrix_present
          uint32 :glyph_count
          array :glyphs, type: :uint16, initial_length: :glyph_count
          array :glyph_positions, type: :point_f, initial_length: :glyph_count
          array :transform_matrix, type: :float, initial_length: 6, onlyif: -> { matrix_present == 1 }
        end
        BODY = DrawDriverStringBody

        def flag_fields = { solid_color: SOLID_COLOR_FLAG, font_object_id: OBJECT_ID_MASK }

        def solid_color? = flags.anybits?(SOLID_COLOR_FLAG)
        def font_object_id = flags & OBJECT_ID_MASK
        def brush_id = body.brush_id
        def options_flags = body.options_flags
        def cmap_lookup? = options_flags.anybits?(CMAP_LOOKUP)
        def matrix_present? = body.matrix_present == 1
        def glyph_count = body.glyph_count
        def glyphs = body.glyphs.to_a
        def glyph_positions = body.glyph_positions.map { |p| [p.x, p.y] }
        def transform_matrix = matrix_present? ? body.transform_matrix.to_a : nil
      end
    end
  end
end
