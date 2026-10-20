# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetTSGraphics (2.3.8.2). Flags bit T says an EmfPlusPalette
      # follows the fixed part, bit V that it holds only basic VGA colours.
      # The palette stays opaque bytes.
      class SetTSGraphics < Base
        TYPE = 0x4039
        PALETTE_FLAG = 0x0001
        VGA_PALETTE_FLAG = 0x0002
        FIXED_SIZE = 36

        class SetTSGraphicsBody < BinData::Record
          endian :little
          mandatory_parameter :data_size
          mandatory_parameter :flags
          uint8 :anti_alias_mode
          uint8 :text_render_hint
          uint8 :compositing_mode
          uint8 :compositing_quality
          int16 :render_origin_x
          int16 :render_origin_y
          uint16 :text_contrast
          uint8 :filter_type
          uint8 :pixel_offset
          array :world_to_device, type: :float, initial_length: 6
          string :palette, read_length: -> { flags.anybits?(PALETTE_FLAG) ? data_size - FIXED_SIZE : 0 }
        end
        BODY = SetTSGraphicsBody

        def flag_fields = { palette: PALETTE_FLAG, vga_palette: VGA_PALETTE_FLAG }

        def palette? = flags.anybits?(PALETTE_FLAG)
        def vga_palette? = flags.anybits?(VGA_PALETTE_FLAG)
        def anti_alias_mode = body.anti_alias_mode.to_i
        def text_render_hint = body.text_render_hint.to_i
        def compositing_mode = body.compositing_mode.to_i
        def compositing_quality = body.compositing_quality.to_i
        def render_origin_x = body.render_origin_x.to_i
        def render_origin_y = body.render_origin_y.to_i
        def text_contrast = body.text_contrast.to_i
        def filter_type = body.filter_type.to_i
        def pixel_offset = body.pixel_offset.to_i
        def world_to_device = body.world_to_device.to_a
        def palette = body.palette.to_s
      end
    end
  end
end
