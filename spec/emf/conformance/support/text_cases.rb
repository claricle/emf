# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted text records: a well-formed one per type, and a mutation that breaks one rule.
    module TextCases
      CraftedEmf = Emf::SpecSupport::CraftedEmf
      PDY = 0x2000
      NO_RECT = 0x100
      DX_UNIT = [116].freeze
      SMALL_CHARS = 0x200

      module_function

      def utf16(string) = string.encode(Encoding::UTF_16LE).b

      # EmrText descriptor (rectangle present unless NO_RECT) with string and Dx at the given record offsets.
      def descriptor(chars:, off_string:, off_dx:, options: 0)
        rect = options.nobits?(NO_RECT) ? [0, 0, -1, -1].pack("l<4") : "".b
        [1, 2, chars, off_string, options].pack("l<2V3") + rect + [off_dx].pack("V")
      end

      # EXTTEXTOUT with the string and Dx right after the 76-byte fixed part (60 with NO_RECT).
      def ext(type: 84, text: "abc", options: 0, **override)
        wide = type == 84
        string = wide ? utf16(text) : text.b
        fixed = options.nobits?(NO_RECT) ? 76 : 60
        off_dx = fixed + ((string.bytesize + 3) & ~3)
        fields = { chars: text.length, off_string: fixed, off_dx: off_dx, options: options }.merge(override)
        dx = (DX_UNIT * text.length * (options.nobits?(PDY) ? 1 : 2)).pack("V*")
        body = [0, 0, 99, 99, 1, 0, 0].pack("l<4V3") + descriptor(**fields)
        CraftedEmf.record(type, body + string.ljust((string.bytesize + 3) & ~3, "\0".b) + dx)
      end

      def small(text: "abc", options: SMALL_CHARS, chars: nil)
        wide = options.nobits?(SMALL_CHARS)
        string = wide ? utf16(text) : text.b
        rect = options.nobits?(NO_RECT) ? [0, 0, -1, -1].pack("l<4") : "".b
        body = [5, 6, chars || text.length, options, 1, 0, 0].pack("l<2V5") + rect + string.ljust((string.bytesize + 3) & ~3, "\0".b)
        CraftedEmf.record(108, body)
      end

      # POLYTEXTOUT of strings, descriptors first (40 bytes with a rectangle) then all buffers.
      def poly(type: 97, texts: %w[ab cde], options: 0, count: texts.size, **override)
        wide = type == 97
        rect_len = options.nobits?(NO_RECT) ? 16 : 0
        entry_len = 24 + rect_len
        cursor = 40 + (entry_len * texts.size)
        entries = "".b
        buffers = "".b
        texts.each do |text|
          string = (wide ? utf16(text) : text.b)
          string = string.ljust((string.bytesize + 3) & ~3, "\0".b)
          dx = (DX_UNIT * text.length).pack("V*")
          fields = { chars: text.length, off_string: cursor, off_dx: cursor + string.bytesize, options: options }.merge(override)
          entries << descriptor(**fields)
          buffers << string << dx
          cursor += string.bytesize + dx.bytesize
        end
        CraftedEmf.record(type, [0, 0, 99, 99, 1, 0, 0, count].pack("l<4V4") + entries + buffers)
      end

      def file(*records) = CraftedEmf.build(records: records)

      # id => [crafted file, ids that fire]
      def cases
        {
          "emf.exttextout.string_bounds" => [file(ext(off_string: 400)), ["emf.exttextout.string_bounds"]],
          "emf.exttextout.string_offset_alignment" => [file(ext(off_string: 77)), ["emf.exttextout.string_offset_alignment"]],
          "emf.exttextout.dx_bounds" => [file(ext(off_dx: 400)), ["emf.exttextout.dx_bounds"]],
          "emf.exttextout.dx_offset_alignment" => [file(ext(off_dx: 83)), ["emf.exttextout.dx_offset_alignment"]],
          "emf.exttextout.string_encoding" => [file(unpaired_surrogate), ["emf.exttextout.string_encoding"]],
          "emf.exttextout.options_defined" => [file(ext(options: 0x8)), ["emf.exttextout.options_defined"]],
          "emf.smalltextout.text_string" => [file(small(chars: 50)), ["emf.smalltextout.text_string"]],
          "emf.smalltextout.options_defined" => [file(small(options: SMALL_CHARS | 0x8)), ["emf.smalltextout.options_defined"]],
          "emf.polytextout.strings" => [file(poly(off_string: 5000)), ["emf.polytextout.strings"]],
          "emf.polytextout.dx" => [file(poly(off_dx: 5000)), ["emf.polytextout.dx"]],
          "emf.polytextout.options_defined" => [file(poly(options: 0x8)), ["emf.polytextout.options_defined"]],
          "emf.opaque.text_arrays" => [file(poly(count: 40)), ["emf.opaque.text_arrays"]]
        }
      end

      def unpaired_surrogate
        record = ext
        record[76, 2] = [0xDF54].pack("v")
        record
      end

      def clean
        [ext, ext(type: 83), ext(options: PDY), ext(options: NO_RECT), small, small(options: 0), small(options: NO_RECT | SMALL_CHARS),
         poly, poly(type: 96), poly(options: NO_RECT)]
      end
    end
  end
end
