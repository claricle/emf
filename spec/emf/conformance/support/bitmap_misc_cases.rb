# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted bitmap, comment, escape, OpenGL and opaque-record files for the W13/W14 rules.
    # Each case is a clean file with one field changed, so the rule under test is the only one that can fire.
    module BitmapMiscCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      FIXED = { 76 => 100, 77 => 108, 78 => 128, 79 => 140, 80 => 76, 81 => 80, 114 => 108, 116 => 108 }.freeze
      SOURCE = { 76 => 80, 77 => 80, 78 => 80, 79 => 92, 80 => 64, 81 => 64, 114 => 80, 116 => 80 }.freeze
      # Offset of offBmiSrc relative to the usage field: usage, offBmi, cbBmi, offBits, cbBits (EMR_SETDIBITSTODEVICE and
      # EMR_STRETCHDIBITS put the buffers first and the usage after them).
      BUFFERS = { 76 => 84, 77 => 84, 78 => 84, 79 => 96, 80 => 48, 81 => 48, 114 => 84, 116 => 84 }.freeze

      # Offsets of the extents the AlphaBlend record needs positive.
      FIXED_EXTENTS = { 114 => [32, 36, 100, 104] }.freeze

      ONE = [1].pack("V").freeze

      module_function

      def bmi(width: 2, height: 2, planes: 1, bit_count: 24, compression: 0, image_size: 0, size: 40)
        [size, width, height, planes, bit_count, compression, image_size, 0, 0, 0, 0].pack("VllvvVVllVV")
      end

      def bits = "\x11".b * 16

      # fields: byte offset => [pack directive, value]; patches applied to the fixed part.
      def bitmap(type, fields: {}, header: bmi, pixels: bits, buffer: nil)
        fixed = FIXED.fetch(type)
        body = ("\0".b * (fixed - 8)).dup
        base = BUFFERS.fetch(type)
        { base => fixed, base + 4 => header.bytesize, base + 8 => fixed + header.bytesize,
          base + 12 => pixels.bytesize }.each do |pos, value|
          body[pos - 8, 4] = [value].pack("V")
        end
        FIXED_EXTENTS.fetch(type, []).each { |pos| body[pos - 8, 4] = ONE }
        fields.each { |pos, (directive, value)| body[pos - 8, [value].pack(directive).bytesize] = [value].pack(directive) }
        CraftedEmf.record(type, body + (buffer || (header + pixels)))
      end

      def file(*records) = CraftedEmf.build(records: records)

      def u32(pos, value) = { pos => ["V", value] }

      def clean_bitmaps
        FIXED.keys.map { |type| bitmap(type) }
      end

      # id => [bytes, ids expected to fire]
      def bitmap_cases
        blt = 76
        {
          "emf.bitmap.record_size" => [file(CraftedEmf.record(76, "\0".b * 40)), %w[emf.bitmap.record_size]],
          "emf.bitmap.usage" => [file(bitmap(blt, fields: u32(80, 7))), %w[emf.bitmap.usage]],
          "emf.bitmap.bmi_range" => [file(bitmap(blt, fields: u32(88, 5000))), %w[emf.bitmap.bmi_range]],
          "emf.bitmap.bits_range" => [file(bitmap(blt, fields: u32(96, 5000))), %w[emf.bitmap.bits_range]],
          "emf.bitmap.buffer_fixed_overlap" => [file(bitmap(blt, fields: u32(84, 52))),
                                                %w[emf.bitmap.buffer_fixed_overlap emf.bitmap.bmi_header_size]],
          "emf.bitmap.buffer_overlap" => [file(bitmap(blt, fields: u32(92, 110))), %w[emf.bitmap.buffer_overlap]],
          "emf.bitmap.bmi_header_size" => [file(bitmap(blt, header: bmi(size: 24))), %w[emf.bitmap.bmi_header_size]],
          "emf.bitmap.bmi_extent" => [file(bitmap(blt, header: bmi(width: 0, height: 0))), %w[emf.bitmap.bmi_extent]],
          "emf.bitmap.bmi_planes" => [file(bitmap(blt, header: bmi(planes: 2), pixels: "\x11".b * 32)), %w[emf.bitmap.bmi_planes]],
          "emf.bitmap.bmi_bitcount" => [file(bitmap(blt, header: bmi(bit_count: 12))), %w[emf.bitmap.bmi_bitcount]],
          "emf.bitmap.bmi_compression" => [file(bitmap(blt, header: bmi(compression: 9, image_size: 16))), %w[emf.bitmap.bmi_compression]],
          "emf.bitmap.bits_length" => [file(bitmap(blt, pixels: "\x11".b * 8)), %w[emf.bitmap.bits_length]],
          "emf.bitmap.mask_monochrome" => [file(mask_blt), %w[emf.bitmap.mask_monochrome]],
          "emf.bitmap.raster_operation" => [file(bitmap(blt, fields: u32(40, 0x01CC0020))), %w[emf.bitmap.raster_operation]],
          "emf.bitmap.rop4_reserved" => [file(bitmap(78, fields: { 40 => ["v", 3] }, buffer: bmi + bits)),
                                         %w[emf.bitmap.rop4_reserved]],
          "emf.bitmap.blend_operation" => [file(bitmap(114, fields: { 40 => ["C", 1] })), %w[emf.bitmap.blend_operation]],
          "emf.bitmap.alpha_format" => [file(bitmap(114, fields: { 43 => ["C", 1] }, header: bmi)), %w[emf.bitmap.alpha_format]],
          "emf.bitmap.positive_extent" => [file(bitmap(114, fields: u32(32, 0))), %w[emf.bitmap.positive_extent]]
        }
      end

      # A MASKBLT whose mask BMI is a 24-bit bitmap: source at the fixed part's end, mask right after the source bits.
      def mask_blt
        fixed = FIXED.fetch(78)
        record = bitmap(78)
        mask_at = fixed + 40 + 16
        patch = record.dup
        { 112 => mask_at, 116 => 40, 120 => mask_at + 40, 124 => 16 }.each { |pos, value| patch[pos, 4] = [value].pack("V") }
        CraftedEmf.record(78, patch.byteslice(8..) + bmi + bits)
      end

      def comment(data, size: nil) = CraftedEmf.record(70, [data.bytesize].pack("V") + data, size: size)

      def public_comment(public_id, rest = "".b) = comment([0x43494447, public_id].pack("V2") + rest)

      def padded(bytes) = bytes.ljust((bytes.bytesize + 3) / 4 * 4, "\0".b)

      def comment_cases
        {
          "emf.comment.padding" => [file(CraftedEmf.record(70, [4].pack("V") + "abcd".b + ("\0".b * 8))), %w[emf.comment.padding]],
          "emf.comment.header_size" => [file(public_comment(2, "\0".b * 4)), %w[emf.comment.header_size]],
          "emf.comment.public_payload" => [file(public_comment(2, group_rect(900)), public_comment(3)), %w[emf.comment.public_payload]],
          "emf.comment.public_identifier" => [file(public_comment(0x1234)), %w[emf.comment.public_identifier]],
          "emf.comment.windows_metafile_reserved" => [file(windows_metafile(flags: 1)), %w[emf.comment.windows_metafile_reserved]],
          "emf.comment.group_unclosed" => [file(public_comment(2, group_rect)), %w[emf.comment.group_unclosed]],
          "emf.comment.group_end" => [file(public_comment(3)), %w[emf.comment.group_end]]
        }
      end

      def group_rect(chars = 0) = [0, 0, 1, 1].pack("l<4") + [chars].pack("V")

      def windows_metafile(flags: 0, size: 4)
        public_comment(0x80000001, [0x300, 0, 0, flags, size].pack("vvVVV") + "wmfd".b)
      end

      def escape(type, fields, tail = "".b) = CraftedEmf.record(type, fields.pack("V*") + tail)

      # CREATECOLORSPACEW whose LogColorSpaceW is well formed but whose cbData (offset 604) runs past the record.
      def colorspace_w_overrun
        log_color_space = [0x50534F43, 0x400, 588, 0, 1].pack("V5") + ("\0".b * 568)
        CraftedEmf.record(122, [1].pack("V") + log_color_space + [0, 40].pack("V2") + "abcd".b)
      end

      def escape_cases
        {
          "emf.escape.record_size" => [file(escape(105, [1])), %w[emf.escape.record_size]],
          "emf.escape.payload_bounds" => [file(escape(106, [1, 64], "abcd".b)), %w[emf.escape.payload_bounds]],
          "emf.escape.driver_name" => [file(escape(110, [1, 3, 0], "abcd".b)), %w[emf.escape.driver_name]],
          "emf.opengl.record_size" => [file(CraftedEmf.record(103, "\0".b * 8)), %w[emf.opengl.record_size]],
          "emf.opengl.payload_bounds" => [file(CraftedEmf.record(102, [999].pack("V") + "abcd".b)), %w[emf.opengl.payload_bounds]],
          "emf.opaque.fixed_size" => [file(CraftedEmf.record(101, "".b)), %w[emf.opaque.fixed_size]],
          "emf.opaque.payload_bounds" => [file(colorspace_w_overrun), %w[emf.opaque.payload_bounds]]
        }
      end

      # Well-formed records the escape/comment/opaque rules must leave alone.
      def clean_misc
        [
          comment("abcd".b), public_comment(2, group_rect) + public_comment(3), windows_metafile,
          escape(105, [1, 4], "abcd".b), escape(106, [1, 0]),
          escape(110, [1, 4, 4], "\x41\0\0\0".b + "abcd".b),
          CraftedEmf.record(102, [4].pack("V") + "abcd".b), CraftedEmf.record(103, ("\0".b * 16) + [0].pack("V")),
          CraftedEmf.record(23, "\0".b * 24), CraftedEmf.record(112, [0, 2, 2].pack("V3") + "abcd".b)
        ]
      end

      def cases = bitmap_cases.merge(comment_cases).merge(escape_cases)
    end
  end
end
