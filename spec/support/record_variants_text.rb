# frozen_string_literal: true

require_relative "record_variants"

# Variants for the text records (MS-EMF 2.2.5 EmrText, 2.3.5.7-2.3.5.8,
# 2.3.5.37): option-dependent rectangle, 8/16-bit characters, optional and
# doubled (ETO_PDY) spacing arrays, empty strings and out-of-range spans.
module RecordVariants
  self.catalog = :text
  SMALL_TEXT_DIAGNOSTIC = "a SmallTextOut body below the fixed prefix stays Raw on both backends, but Ruby reports " \
                          "ParseError 108 and native reports no diagnostic"
  ETO_NO_RECT = 0x100
  ETO_SMALL_CHARS = 0x200
  ETO_PDY = 0x2000
  TEXT_BOUNDS = [-5, -6, 70, 80].freeze
  TEXT_RECT = [1, -2, 300, 400].freeze
  FAR_STRING_DESCRIPTOR = ([1, 2, 3, 4096, 0].pack("l<2V3") + ("\0" * 20)).b.freeze

  module TextBuilders
    def align4(bytes)
      bytes += "\0".b until (bytes.bytesize % 4).zero?
      bytes
    end

    # EMR_EXTTEXTOUTA/W: fixed prefix, optional rectangle, then string and Dx buffers.
    def ext_text(chars:, options:, text:, dx: nil, off_string: nil, off_dx: nil)
      fixed = options.anybits?(ETO_NO_RECT) ? 60 : 76
      string = align4(text.b)
      off_string ||= text.empty? ? 0 : fixed
      off_dx ||= dx ? fixed + string.bytesize : 0
      payload = string + (dx ? dx.pack("V*") : "".b)
      rcl = options.anybits?(ETO_NO_RECT) ? [] : rectl("rcl", *TEXT_RECT)
      [rectl("rcl_bounds", *TEXT_BOUNDS), u32("i_graphics_mode", 2), f32("ex_scale", 1.25), f32("ey_scale", -0.5),
       pointl("ptl_reference", 10, -20), u32("n_chars", chars), u32("off_string", off_string), u32("f_options", options),
       rcl, u32("off_dx", off_dx), raw("trailing", payload)]
    end

    # One EmrText descriptor array plus payload for POLYTEXTOUTA/W (offsets are record relative).
    def poly_text(width, entries)
      start = 40 + entries.sum { |entry| entry[:options].anybits?(ETO_NO_RECT) ? 24 : 40 }
      payload = "".b
      descriptors = "".b
      checks = []
      entries.each_with_index do |entry, index|
        descriptors << poly_descriptor(width, entry, start, payload, index, checks)
      end
      poly_header(entries.size) + pad(descriptors + payload) + checks
    end

    def poly_descriptor(width, entry, start, payload, index, checks)
      text = entry.fetch(:text).b
      off_string = text.empty? ? 0 : start + payload.bytesize
      payload << align4(text)
      dx = entry[:dx]
      off_dx = dx ? start + payload.bytesize : 0
      payload << dx.pack("V*") if dx
      rect = entry[:options].anybits?(ETO_NO_RECT) ? "".b : TEXT_RECT.pack("l<4")
      checks.push(*check("text_bytes(#{index})", text), *check("dx_bytes(#{index})", dx&.pack("V*")),
                  *check("entry_bounds(#{index})", rect.empty? ? nil : rect))
      [index - 4, 12 + index].pack("l<2") + [text.bytesize / width, off_string, entry[:options]].pack("V3") + rect + [off_dx].pack("V")
    end

    def poly_header(count)
      bounds = TEXT_BOUNDS.pack("l<4")
      pad(bounds) + check("bounds", bounds) + [Field.new(nil, "V", 2), Field.new(nil, "e", 1.25), Field.new(nil, "e", -0.5)] +
        check("c_strings", count) + [Field.new(nil, "V", count)]
    end
  end
  Entry.include(TextBuilders)

  POLY_TEXT_DIAGNOSTIC = "Divergence: native validates PolyTextOut descriptor and span bounds at parse and emits a " \
                         "ParseError (record_code 96/97); Ruby parses the same bytes with no diagnostic and only raises " \
                         "ArgumentError from the span accessors. Wire class and exact serialization agree."
  UTF16_ABC = "A\0B\0C\0".b
  SURROGATES = "\x3D\xD8\x00\xDE\x00\xD8".b # U+1F600 pair followed by a lone high surrogate

  { "ExtTextOutW" => [84, 2], "ExtTextOutA" => [83, 1] }.each do |name, (type, width)|
    define(name, type) do
      three = width == 2 ? UTF16_ABC : "ABC".b
      valid("empty string, no spacing", ext_text(chars: 0, options: 0, text: ""))
      valid("one character with spacing", ext_text(chars: 1, options: 0, text: three.byteslice(0, width), dx: [7]))
      valid("three characters opaque+clipped with padding", ext_text(chars: 3, options: 6, text: three, dx: [7, 8, 0xFFFF_FFFF]))
      valid("ETO_NO_RECT omits the rectangle", ext_text(chars: 3, options: ETO_NO_RECT, text: three, dx: [1, 2, 3]))
      valid("ETO_PDY carries two spacing values per character",
            ext_text(chars: 2, options: ETO_PDY, text: three.byteslice(0, 2 * width), dx: [1, 2, 3, 4]))
      valid("no spacing array (offDx 0)", ext_text(chars: 3, options: 0, text: three))
      valid("high-bit and surrogate character codes",
            ext_text(chars: 3, options: 0, text: width == 2 ? SURROGATES : "\x80\xFF\x00".b, dx: [1, 1, 1]))
      valid("ETO_SMALL_CHARS flag does not change field layout", ext_text(chars: 3, options: ETO_SMALL_CHARS, text: three, dx: [1, 2, 3]))
      malformed("offString beyond record", ext_text(chars: 3, options: 0, text: three, dx: [1, 2, 3], off_string: 4096))
      malformed("offDx beyond record", ext_text(chars: 3, options: 0, text: three, dx: [1, 2, 3], off_dx: 4096))
      malformed("nChars exceeds record", ext_text(chars: UINT_MAX, options: 0, text: three, dx: [1, 2, 3]))
      malformed("string offset inside fixed prefix", ext_text(chars: 3, options: 0, text: three, dx: [1, 2, 3], off_string: 8))
      malformed("string and spacing overlap", ext_text(chars: 3, options: 0, text: three, dx: [1, 2, 3], off_dx: 76))
    end
  end

  { "PolyTextOutA" => [96, 1], "PolyTextOutW" => [97, 2] }.each do |name, (type, width)|
    define(name, type) do
      text = width == 2 ? UTF16_ABC : "ABC".b
      valid("zero strings", poly_header(0))
      valid("one string with rectangle and spacing", poly_text(width, [{ options: 0, text: text, dx: [4, 5, 6] }]))
      valid("one string without rectangle or spacing", poly_text(width, [{ options: ETO_NO_RECT, text: text }]))
      valid("mixed entries including an empty string",
            poly_text(width, [{ options: 0, text: text, dx: [1, 2, 3] }, { options: ETO_NO_RECT, text: "" }]))
      valid("ETO_PDY doubles the spacing words",
            poly_text(width, [{ options: ETO_PDY, text: text.byteslice(0, 2 * width), dx: [1, 2, 3, 4] }]))
      pending_derived(:truncated, POLY_TEXT_DIAGNOSTIC)
      malformed("count exceeds descriptors", poly_header(5), pad("\0" * 40), pending: POLY_TEXT_DIAGNOSTIC)
      malformed("string offset beyond record", poly_header(1),
                pad(FAR_STRING_DESCRIPTOR), pending: POLY_TEXT_DIAGNOSTIC)
    end
  end

  # EMR_SMALLTEXTOUT: bounds present unless ETO_NO_RECT; 8-bit text with ETO_SMALL_CHARS.
  define("SmallTextOut", 108) do
    small = lambda do |chars, options, text|
      has_bounds = options.nobits?(ETO_NO_RECT)
      [i32("x_dest", -12), i32("y_dest", 25), u32("c_chars", chars), u32("fu_options", options), u32("i_graphics_mode", 2),
       f32("ex_scale", 1.0), f32("ey_scale", -2.0),
       (has_bounds ? check("bounds", TEXT_BOUNDS.pack("l<4")) + pad(TEXT_BOUNDS.pack("l<4")) : check("bounds", nil)),
       check("text_bytes", text.b), pad(text.b), pad("\0" * ((4 - ((36 + (has_bounds ? 16 : 0) + text.bytesize) % 4)) % 4))].flatten
    end
    [[0, 0, "".b], [0, ETO_NO_RECT, "".b]].each do |chars, options, text|
      valid("zero characters options #{options}", small.call(chars, options, text))
    end
    [0, ETO_NO_RECT, ETO_SMALL_CHARS, ETO_NO_RECT | ETO_SMALL_CHARS].each do |options|
      text = options.anybits?(ETO_SMALL_CHARS) ? "\x00\x80\xFF".b : "\x00\x00\x80\xFF\xFF\x7F".b
      valid("three characters options 0x#{options.to_s(16)}", small.call(3, options, text))
      valid("one character options 0x#{options.to_s(16)}",
            small.call(1, options, text.byteslice(0, options.anybits?(ETO_SMALL_CHARS) ? 1 : 2)))
    end
    malformed("character count exceeds payload", i32("x_dest", 0), i32("y_dest", 0), u32("c_chars", 9), u32("fu_options", 0),
              u32("i_graphics_mode", 1), f32("ex_scale", 1.0), f32("ey_scale", 1.0), pad("\0" * 16))
    malformed("body shorter than fixed prefix", pad("\0" * 4), raw: true, pending: SMALL_TEXT_DIAGNOSTIC)
  end
end
