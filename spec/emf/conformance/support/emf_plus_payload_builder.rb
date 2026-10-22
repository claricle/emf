# frozen_string_literal: true

require_relative "emf_plus_builder"

module Emf
  module SpecSupport
    # Crafted EMF+ payload records and objects for emf_plus_payloads_spec.rb. Adds helpers only.
    module EmfPlusPayloadBuilder
      B = EmfPlusBuilder
      BLUR_GUID = "633c80a4-1843-482b-9ef2-be2834c5fdd4"
      GRAPHICS_VERSION = [0xDBC01002].pack("V")

      module_function

      # EmfPlusDrawDriverString holding `count` glyphs; overrides replace the real values to break them.
      def driver_string(count: 3, matrix: false, options: 1, matrix_present: nil, glyph_count: nil, size: nil, data_size: nil)
        body = [0xFF0000FF, options, matrix_present || (matrix ? 1 : 0), glyph_count || count].pack("V4") +
               Array.new(count) { |i| 0x41 + i }.pack("v*") + B.points(count) + (matrix ? B.float(1, 0, 0, 1, 0, 0) : "")
        B.record(0x4036, flags: 0x8000, body: body, size: size, data_size: data_size)
      end

      def draw_string(text: "abc", length: nil, size: nil, data_size: nil, padding: 0)
        body = [0xFF0000FF, 0xFFFFFFFF, length || text.length].pack("V3") + B.rect_f + text.encode("UTF-16LE").b + ("\0" * padding)
        B.record(0x401C, flags: 0x8000, body: body, size: size, data_size: data_size)
      end

      # DrawImage; `compressed` selects the EmfPlusRect (C) form.
      def draw_image(compressed: false, size: nil, data_size: nil)
        rect = compressed ? [0, 0, 10, 10].pack("s4") : B.rect_f
        B.record(0x401A, flags: compressed ? 0x4000 : 0, body: [0, 2].pack("V2") + B.rect_f + rect, size: size, data_size: data_size)
      end

      def draw_image_points(flags: 0, size: nil, data_size: nil)
        points = flags.anybits?(0x0800) ? [1, 1, 1, 1, 1, 1].pack("c*") : B.points(3)
        points = [0, 0, 1, 1, 2, 2].pack("s6") if flags.anybits?(0x4000) && !flags.anybits?(0x0800)
        B.record(0x401B, flags: flags, body: [0, 2].pack("V2") + B.rect_f + [3].pack("V") + points, size: size, data_size: data_size)
      end

      def guid_bytes(text)
        parts = text.split("-")
        [parts[0], parts[1], parts[2]].map { |part| [part].pack("H*").reverse }.join + [parts[3], parts[4]].pack("H*H*")
      end

      def serializable(guid: BLUR_GUID, buffer: B.float(1.5) + [0].pack("V"), buffer_size: nil, size: nil, data_size: nil)
        body = guid_bytes(guid) + [buffer_size || buffer.bytesize].pack("V") + buffer
        B.record(0x4038, body: body, size: size, data_size: data_size)
      end

      def ts_clip(count: 2, compressed: false, data: nil, size: nil, data_size: nil)
        data ||= "\0" * (count * (compressed ? 4 : 8))
        B.record(0x403A, flags: (compressed ? 0x8000 : 0) | count, body: data, size: size, data_size: data_size)
      end

      def palette(count = 2) = [0, count].pack("V2") + ([0xFF112233].pack("V") * count)

      TS_DEFAULTS = { anti_alias: 0, text_hint: 0, compositing_mode: 0, compositing_quality: 1, contrast: 0, filter: 0,
                      pixel_offset: 0 }.freeze

      def ts_graphics(palette: nil, size: nil, data_size: nil, **fields)
        v = TS_DEFAULTS.merge(fields)
        body = [v[:anti_alias], v[:text_hint], v[:compositing_mode],
                v[:compositing_quality]].pack("C4") + [0, 0, v[:contrast]].pack("s2S") +
               [v[:filter], v[:pixel_offset]].pack("C2") + B.float(1, 0, 0, 1, 0, 0) + palette.to_s
        B.record(0x4039, flags: palette ? 1 : 0, body: body, size: size, data_size: data_size)
      end

      def font(char_count: 3, family: "Arial", declared: nil)
        GRAPHICS_VERSION + B.float(12) + [2, 0, 0, declared || char_count].pack("V4") + family.encode("UTF-16LE").b
      end

      # EmfPlusImage ObjectData around a bitmap of `stride`/`bitmap_type`, or a metafile.
      def bitmap_image(image_type: 1, stride: 8, bitmap_type: 0, pixels: "\0" * 16)
        GRAPHICS_VERSION + [image_type, 2, 2, stride, 0x26200A, bitmap_type].pack("V6") + pixels
      end

      def metafile_image(type: 3, data: "\0" * 8, declared: nil)
        GRAPHICS_VERSION + [2, type, declared || data.bytesize].pack("V3") + data
      end
    end
  end
end
