# frozen_string_literal: true

require_relative "bitmap_misc_cases"

module Emf
  module SpecSupport
    # Crafted files for the rules that replaced "deferred, readable from the record bytes" manifest rows:
    # colour table, ColorRef reserved byte, BitmapV5 intent, BEGINGROUP description, MULTIFORMATS
    # signature / EPS version and the CreateColorSpace LogColorSpace fields. Each case is a clean
    # file with one field changed.
    module DeferredCases
      Base = Emf::SpecSupport::BitmapMiscCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      ENHMETA = 0x464D4520
      EPS = 0x46535045

      module_function

      # A BitmapInfoHeader with its ColorUsed (the shared Base.bmi leaves it zero).
      def bmi(color_used: 0, **options)
        Base.bmi(**options).tap { |header| header[32, 4] = [color_used].pack("V") }
      end

      def table(entries, size: 4) = "\0".b * (entries * size)

      def bitmap(header:, pixels: Base.bits, type: 76, fields: {}) = Base.bitmap(type, fields: fields, header: header, pixels: pixels)

      def v5_header(intent)
        header = bmi(size: 124) + ("\0".b * 84)
        header[108, 4] = [intent].pack("V")
        header
      end

      def multiformats(signature, version = 1)
        rect = [0, 0, 1, 1].pack("l<4")
        Base.public_comment(0x40000004, rect + [1].pack("V") + [signature, version, 8, 44].pack("V4") + "datadata".b)
      end

      def group(chars, text) = Base.public_comment(2, Base.group_rect(chars) + text) + Base.public_comment(3)

      # 340-byte EMR_CREATECOLORSPACE: ihCS then a LogColorSpace (Signature, Version, Size, Type, Intent, ...).
      def color_space(signature: 0x50534F43, version: 0x400, type: 0, intent: 1)
        lcs = [signature, version, 328, type, intent].pack("V5").ljust(328, "\0".b)
        CraftedEmf.record(99, [1].pack("V") + lcs)
      end

      def bitmap_cases
        {
          "emf.bitmap.color_table" => [Base.file(bitmap(header: bmi(bit_count: 1, color_used: 2) + table(1))),
                                       %w[emf.bitmap.color_table]],
          "emf.bitmap.color_table_length" => [Base.file(bitmap(header: bmi(bit_count: 8) + table(100))),
                                              %w[emf.bitmap.color_table_length]],
          "emf.bitmap.bmi_v5_intent" => [Base.file(bitmap(header: v5_header(3))), %w[emf.bitmap.bmi_v5_intent]],
          "emf.bitmap.colorref_reserved" => [Base.file(bitmap(header: bmi, fields: { 79 => ["C", 0x80] })),
                                             %w[emf.bitmap.colorref_reserved]],
          "emf.bitmap.colorref_palette" => [Base.file(bitmap(header: bmi, fields: { 79 => ["C", 0x02] })),
                                            %w[emf.bitmap.colorref_palette]]
        }
      end

      def comment_cases
        {
          "emf.comment.group_description" => [Base.file(group(2, "A\0B\0".b)), %w[emf.comment.group_description]],
          "emf.comment.multiformats_signature" => [Base.file(multiformats(0x12345678)), %w[emf.comment.multiformats_signature]],
          "emf.comment.multiformats_eps_version" => [Base.file(multiformats(EPS, 2)), %w[emf.comment.multiformats_eps_version]],
          "emf.opaque.colorspace_fields" => [Base.file(color_space(version: 0x300)), %w[emf.opaque.colorspace_fields]]
        }
      end

      # Well-formed records the new rules must leave alone.
      def clean_bitmaps
        [bitmap(header: bmi(bit_count: 1, color_used: 2) + table(2)), bitmap(header: bmi(bit_count: 8) + table(256)),
         bitmap(header: bmi(bit_count: 4, color_used: 3) + table(3)), bitmap(header: bmi(bit_count: 1) + table(2), type: 114),
         bitmap(header: bmi(bit_count: 8) + table(300)), bitmap(header: v5_header(4)),
         bitmap(header: bmi(bit_count: 1, color_used: 2) + table(2, size: 2), fields: Base.u32(80, 1))]
      end

      def clean_comments
        [multiformats(ENHMETA), multiformats(EPS, 1), group(1, "A\0\0\0".b), group(2, "A\0\0\0".b), group(0, "".b),
         color_space, color_space(type: 0x73524742, intent: 8)]
      end
    end
  end
end
