# frozen_string_literal: true

require_relative "record_variants_bitmap"

# Variants for object-creating and palette records (MS-EMF 2.2.13 LogFont,
# 2.2.14 LogFontExDv, 2.2.22 LogPenEx, 2.3.7.8-2.3.7.9 palette records,
# 2.3.5.12 GradientFill): font layout forms, user-style pens with bitmap
# brushes, palette entry flags and counts, and gradient vertex/mode payloads.
module RecordVariants
  self.catalog = :objects
  FACENAME = [0xD800, 0x0041, 0xFFFF].freeze
  FONT_NAMES = [FACENAME + ([0] * 29), (1..64).to_a, (101..132).to_a].freeze

  module ObjectBuilders
    def u16s(values) = values.pack("v*").b

    def logfont_bytes(height)
      [height, 7, -3, 4, 900].pack("l<5") + [1, 0, 1, 2, 3, 4, 5, 0x42].pack("C8") + u16s(FONT_NAMES[0])
    end

    def logfont_checks(path, height)
      check("#{path}.height", height) + check("#{path}.width", 7) + check("#{path}.escapement", -3) + check("#{path}.weight", 900) +
        check("#{path}.facename.snapshot", FONT_NAMES[0])
    end

    def font_record(body, checks)
      u32("ih_object", 0x8000_0001) + pad(body) + checks
    end

    def panose_bytes(height)
      logfont_bytes(height) + u16s(FONT_NAMES[1]) + u16s(FONT_NAMES[2]) + [1, 2, 3, 4].pack("V4") + "ABCD".b +
        [0xFFFF_FFFF].pack("V") + (1..12).to_a.pack("C*")
    end

    def exdv_bytes(height, axes, trailing)
      logfont_bytes(height) + u16s(FONT_NAMES[1]) + u16s(FONT_NAMES[2]) + u16s(FONT_NAMES[2]) +
        [0x08007664, axes.size].pack("V2") + axes.pack("l<*") + trailing
    end

    # Extended pen: fixed part, user styles, then placed bitmap buffers.
    def pen_record(styles:, buffers: [nil, nil], order: nil, gap: 0, pen: [0x0001_0007, 5, 1])
      fixed = 52 + (4 * styles.size)
      pairs, tail = place(buffers, fixed, order, gap)
      head = u32("ih_pen", 5) + u32("off_bmi", pairs[0][0]) + u32("cb_bmi", pairs[0][1]) + u32("off_bits", pairs[1][0]) +
             u32("cb_bits", pairs[1][1]) + u32("pen_style", pen[0]) + u32("width", pen[1]) + u32("brush_style", pen[2]) +
             colorref("color", 10, 20, 30, 4) + u32("brush_hatch", 6) + u32("num_style_entries", styles.size)
      head + u32_list("style_entries", styles) + pad(tail)
    end

    def palette_entries(path, entries)
      entries.each_with_index.flat_map do |(red, green, blue, flags), i|
        u8("#{path}[#{i}].red", red) + u8("#{path}[#{i}].green", green) + u8("#{path}[#{i}].blue", blue) + u8("#{path}[#{i}].flags", flags)
      end
    end

    def palette_cases(prefix_fields)
      PALETTE_CASES.each do |label, entries, trailing|
        valid(label, prefix_fields.call(entries.size), palette_entries("palette_entries", entries), check("trailing", trailing),
              pad(trailing))
      end
      malformed("entry count exceeds record", prefix_fields.call(9), palette_entries("palette_entries", PALETTE_CASES[1][1]))
      malformed("entry count max", prefix_fields.call(UINT_MAX), palette_entries("palette_entries", PALETTE_CASES[1][1]))
    end
  end
  Entry.include(ObjectBuilders)

  PALETTE_CASES = [
    ["no entries", [], "".b], ["one entry", [[1, 2, 3, 1]], "".b],
    ["flags reserved explicit nocollapse", [[255, 0, 128, 1], [0, 255, 0, 2], [9, 9, 9, 4], [0, 0, 0, 0xFF]], "".b],
    ["trailing bytes", [[7, 8, 9, 0]], "\x11\x22\x33".b]
  ].freeze
  GRADIENT_RECT_DIAGNOSTIC = "native sizes every gradient element at 12 bytes and keeps rectangle-mode records with " \
                             "8-byte GRADIENT_RECT elements (MS-EMF 2.3.5.12) as Raw; Ruby keeps them typed"
  GRADIENT_MODE_DIAGNOSTIC = "native falls back to Raw with ParseError 108 for a gradient mode above 2; Ruby keeps the typed record"
  GRADIENT_BOUNDS_DIAGNOSTIC = "native falls back to Raw with ParseError 108 when the counts exceed the record; " \
                               "Ruby keeps the typed record with no diagnostic"
  PEN_BMI = [40, 2, -2, 1, 32, 0, 16, 0, 0, 0, 0].pack("VllvvVVllVV").freeze
  PEN_BITS = (1..16).to_a.pack("C*").freeze

  define("CreateFontIndirectW", 82, hydrated: true) do
    valid("LogFont only", font_record(logfont_bytes(INT_MIN), logfont_checks("elw", INT_MIN)))
    valid("LogFont with four suffix bytes (partial Panose form)",
          font_record(logfont_bytes(-12) + "TAIL".b, logfont_checks("elw.log_font", -12)))
    valid("LogFontPanose", font_record(panose_bytes(33), logfont_checks("elw.log_font", 33) + check("elw.version", 1) +
                                                   check("elw.vendor_id.snapshot", "ABCD".bytes)))
    valid("LogFontExDv without axes", font_record(exdv_bytes(5, [], "".b), logfont_checks("elw.log_font", 5) +
                                                                   check("elw.design_vector.num_axes", 0)))
    valid("LogFontExDv with axes and suffix", font_record(exdv_bytes(-5, [INT_MIN, INT_MAX], "TAIL".b),
                                                          logfont_checks("elw.log_font", -5) +
                                                          check("elw.design_vector.axis_values.snapshot", [INT_MIN, INT_MAX]) +
                                                          check("elw.trailing.snapshot", "TAIL")))
    malformed("body shorter than LogFont", u32("ih_object", 1), pad("\0".b * 16))
    malformed("design vector axes exceed record", u32("ih_object", 1), pad(exdv_bytes(1, [1], "".b).byteslice(0, 360) + [1, 99].pack("V2")))
  end

  define("ExtCreatePen", 95) do
    bmp = [PEN_BMI.b, PEN_BITS.b]
    valid("solid, no styles, no bitmap", pen_record(styles: [], pen: [0, 1, 0]))
    valid("user styles", pen_record(styles: [1, 0, UINT_MAX]))
    valid("DIB pattern brush, header then bits", pen_record(styles: [], buffers: bmp, pen: [0x0001_0000, UINT_MAX, 5]))
    valid("bits before header", pen_record(styles: [2], buffers: bmp, order: [1, 0]))
    valid("gap before buffers", pen_record(styles: [], buffers: bmp, gap: 4))
    valid("header only", pen_record(styles: [], buffers: [PEN_BMI.b, nil]))
    valid("bits only", pen_record(styles: [3], buffers: [nil, PEN_BITS.b]))
    malformed("style count exceeds record", u32("ih_pen", 1),
              pad(([0] * 8).pack("V8") + [0, 1, 0, 0].pack("V4") + [0, 0xFFFF, 0].pack("V3")))
  end

  define("CreatePalette", 49) do
    palette_cases(->(count) { u32("ih_pal", 2) + u16("version", 0x300) + u16("entry_count", count) })
  end

  define("SetPaletteEntries", 50) do
    palette_cases(->(count) { u32("ih_pal", 2) + u32("start", 3) + u32("entry_count", count) })
  end

  define("ResizePalette", 51) do
    valid("grow", u32("ih_pal", 2), u32("entry_count", 256))
    valid("zero", u32("ih_pal", 0), u32("entry_count", 0))
    valid("max", u32("ih_pal", UINT_MAX), u32("entry_count", UINT_MAX))
  end

  define("SelectPalette", 48) do
    valid("handle 1", u32("ih_pal", 1))
    valid("stock default palette", u32("ih_pal", 0x8000_000F))
  end

  define("RealizePalette", 52) { valid("header only (8 bytes)") }

  define("GradientFill", 118, hydrated: true) do
    pending_derived(:truncated, GRADIENT_BOUNDS_DIAGNOSTIC)
    vertex = ->(x, y, red) { [x, y].pack("l<2") + [red, 0x8000, 0, 0xFFFF].pack("v4") }
    rect_verts = vertex.call(0, 0, 0xFFFF) + vertex.call(INT_MIN, INT_MAX, 0)
    tri_verts = vertex.call(1, 2, 3) + vertex.call(4, 5, 6) + vertex.call(-7, -8, 9)
    wide_rect = rect_verts + [0, 1, 0xDEADBEEF].pack("V3")
    # [label, mode, vertices, elements, body, pending]; MS-EMF sizes a GRADIENT_RECT at 8 bytes.
    [["horizontal rectangle, 8-byte element", 0, 2, 1, rect_verts + [0, 1].pack("V2"), GRADIENT_RECT_DIAGNOSTIC],
     ["vertical rectangle, 8-byte element", 1, 2, 1, rect_verts + [1, 0].pack("V2"), GRADIENT_RECT_DIAGNOSTIC],
     ["two rectangles, 8-byte elements", 0, 2, 2, rect_verts + [0, 1, 1, 0].pack("V4"), GRADIENT_RECT_DIAGNOSTIC],
     ["horizontal rectangle, 12-byte element", 0, 2, 1, wide_rect, nil],
     ["vertical rectangle, 12-byte element", 1, 2, 1, wide_rect, nil],
     ["undefined mode, 12-byte element", 7, 2, 1, wide_rect, GRADIENT_MODE_DIAGNOSTIC],
     ["no vertices or elements", 0, 0, 0, "".b, nil],
     ["triangle", 2, 3, 1, tri_verts + [0, 1, 2].pack("V3"), nil]].each do |label, mode, verts, elements, body, pending|
      valid(label, rectl("rcl_bounds", -1, -2, 30, 40), u32("n_ver", verts), u32("n_tri", elements), u32("ul_mode", mode),
            raw("body", body), pending: pending)
    end
    malformed("vertex count exceeds record", rectl("rcl_bounds", 0, 0, 1, 1), u32("n_ver", 99), u32("n_tri", 1), u32("ul_mode", 0),
              pad("\0".b * 16), pending: GRADIENT_BOUNDS_DIAGNOSTIC)
    malformed("counts max", rectl("rcl_bounds", 0, 0, 1, 1), u32("n_ver", UINT_MAX), u32("n_tri", UINT_MAX), u32("ul_mode", 2),
              pending: GRADIENT_BOUNDS_DIAGNOSTIC)
  end
end
