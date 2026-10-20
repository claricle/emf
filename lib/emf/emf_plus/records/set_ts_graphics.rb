# frozen_string_literal: true

require "emf/emf_plus/records/primitives/palette"

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetTSGraphics (2.3.8.2). Flags bit T says an EmfPlusPalette
      # follows the fixed part, bit V that it holds only basic VGA colours.
      # `palette` is the raw palette bytes so any record re-encodes exactly;
      # `decoded_palette` reads them as an EmfPlusPalette, or is nil when T is
      # clear or the bytes are not exactly one palette.
      class SetTSGraphics < Base
        TYPE = 0x4039
        PALETTE_FLAG = 0x0001
        VGA_PALETTE_FLAG = 0x0002
        FIXED_SIZE = 36

        class SetTSGraphicsBody < Body
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
        alias palette_bytes palette

        def decoded_palette
          return unless palette?

          decoded = Primitives::Palette.read(palette)
          decoded if decoded.num_bytes == palette.bytesize
        rescue IOError
          nil
        end

        # Besides the base edits, `with(decoded_palette: {...})` takes a Hash of
        # EmfPlusPalette fields: it sets T and replaces the palette bytes.
        # PaletteCount defaults to the number of entries given.
        private

        def edited_flags(edits)
          super(edits.key?(:decoded_palette) ? edits.merge(palette: true) : edits)
        end

        def edited_body(new_flags, edits)
          return super unless edits.key?(:decoded_palette)

          super(new_flags, edits.except(:decoded_palette)).tap do |fresh|
            fresh.palette = palette_bytes_for(edits[:decoded_palette])
          end
        end

        def palette_bytes_for(fields)
          count = fields.fetch(:palette_count) { Array(fields[:palette_entries]).size }
          Primitives::Palette.new(fields.merge(palette_count: count)).to_binary_s
        end
      end
    end
  end
end
