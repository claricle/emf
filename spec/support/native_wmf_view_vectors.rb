# frozen_string_literal: true

require_relative "wmf_embedded_emf"

# Synthetic WMF records covering every typed view (DIB, Bitmap16, brush target, Escape, embedded EMF).
module NativeWmfViewVectors
  include WmfEmbeddedEmfSupport

  USAGES = [0, 1, 2, 3].freeze
  SCAN_FIELDS = ([1] * 8).freeze
  BRUSH_STYLES = [[0, 0], [0, 1], [0, 2], [3, 7], [1, 0], [3, 2]].freeze

  def rop = [0xFEDCBA98].pack("V")
  def blt_geometry = [-5, 4, -3, 2, 1, 0].pack("s<*")
  def stretch_geometry = [-7, 8, -5, 4, -3, 2, 1, 0].pack("s<*")
  def bitmap16 = [-7, 9, 2, 2].pack("s<4") + [1, 1, 0xAA, 0x80, 0x55, 0, 0xBE, 0xEF].pack("C*")
  def masks = [0xF800, 0x7E0, 0x1F].pack("V3")

  def info(width, height, bits, compression, image_size, used, size: 40)
    [size, width, height].pack("Vl<2") + [1, bits].pack("v2") +
      [compression, image_size, 123, 456, used, 7].pack("V2l<2V2")
  end

  def packed(usage: 0)
    colors = usage == 1 ? [7, 0, 8, 0] : [1, 2, 3, 4, 5, 6, 7, 8]
    info(1, 1, 8, 0, 0, 2) + colors.pack("C*") + [0, 0xEE, 0xDD, 0xCC].pack("C*")
  end

  def core_dib
    [12, 3, 2, 1, 1].pack("Vv4") + [1, 2, 3, 4, 5, 6].pack("C*") + [0xA0, 0x91, 0x82, 0x73, 0x60, 0x51, 0x42, 0x33, 0xCC, 0xDD].pack("C*")
  end

  def masked_dib(size)
    bytes = info(1, 1, 16, 3, 99, 0)
    bytes[0, 4] = [size].pack("V")
    bytes += masks
    bytes = bytes.ljust(size, "\x59".b) if size > 40
    bytes + [0x1F, 0, 0xAB, 0xCD, 0xEF, 0].pack("C*")
  end

  def v5_profile_dib
    bytes = info(1, 1, 24, 0, 0, 0)
    bytes[0, 4] = [124].pack("V")
    bytes = bytes.ljust(124, "\0".b)
    bytes[56, 4] = [0x4D424544].pack("V")
    bytes[112, 8] = [130, 3].pack("V2")
    bytes + [1, 2, 3, 0, 0xFE, 0xED, 7, 8, 9].pack("C*")
  end

  def rle_dib(compression, bits)
    info(10, 20, bits, compression, 5, 0) + [0xFF, 0, 0x98, 0x76, 0x54, 0xAA].pack("C*")
  end

  def dibs
    [packed, core_dib, masked_dib(40), masked_dib(124), v5_profile_dib, rle_dib(1, 8), rle_dib(13, 4),
     info(3, -2, 24, 0, 0xFFFFFFFF, 0) + (0...24).to_a.pack("C*") + "\xFE\xED".b,
     packed.byteslice(0, 30), "\0".b * 8, info(1, 1, 8, 3, 4, 0) + ("\0" * 4)]
  end

  def bitmap_wire
    blt = rop + blt_geometry
    stretch = rop + stretch_geometry
    absent_blt = rop + [-5, 4].pack("s<2") + [0xCAFE].pack("v") + [-3, 2, 1, 0].pack("s<*")
    absent_stretch = rop + [-7, 8, -5, 4].pack("s<4") + [0xBEEF].pack("v") + [-3, 2, 1, 0, 5, 6].pack("s<*")
    [native_wmf_record(0x0922, blt + bitmap16), native_wmf_record(0x0922, absent_blt),
     native_wmf_record(0x0922, blt + [1, 1, 0, 0].pack("s<4")), native_wmf_record(0x0B23, stretch + bitmap16),
     native_wmf_record(0x0B23, absent_stretch),
     native_wmf_record(0x0B23, stretch + bitmap16.byteslice(0, 8)),
     native_wmf_record(0x0922, blt + [0, 3, 0, 1, 0, 1, 0, 0, 0, 0].pack("s<5") + [1, 8].pack("C2") + ("\0" * 100))] +
      dibs.flat_map { |bytes| dib_blits(bytes) }
  end

  def dib_blits(bytes)
    bytes += "\0".b if bytes.bytesize.odd?
    [0x0940, 0x0B41].map { |function| native_wmf_record(function, rop + (function == 0x0940 ? blt_geometry : stretch_geometry) + bytes) } +
      USAGES.map { |usage| native_wmf_record(0x0D33, [usage, *SCAN_FIELDS].pack("v*") + bytes) } +
      USAGES.map { |usage| native_wmf_record(0x0F43, rop + [usage].pack("v") + stretch_geometry + bytes) }
  end

  def brush_wire
    dibs.flat_map do |bytes|
      bytes += "\0".b if bytes.bytesize.odd?
      BRUSH_STYLES.map { |style, usage| native_wmf_record(0x0142, [style, usage].pack("v2") + bytes) }
    end
  end

  FIXED_ESCAPES = {
    0x1001 => [9, 0xFFFF].pack("v2"), 0x0019 => [-1, 2, 3, -4].pack("l<4") + [5, 6].pack("v2"), 0x0021 => [1].pack("v"),
    0x1019 => [-3].pack("l<"), 0x0008 => [0x1234].pack("v"), 0x0011 => [3].pack("v"), 0x0015 => [-2].pack("l<"),
    0x0016 => [0x7FFFFFFF].pack("l<"), 0x0017 => [-0x80000000].pack("l<")
  }.freeze

  def escape_wire
    empty = Emf::Wmf::EscapeViews::EMPTY.keys.map { |code| native_wmf_escape(code, "".b) }
    fixed = FIXED_ESCAPES.map { |code, data| native_wmf_escape(code, data) }
    empty + fixed + counted_escape_wire + mismatched_escape_wire + passthrough_escape_wire + embedded_segment_wire
  end

  def counted_escape_wire
    Emf::Wmf::EscapeViews::COUNTED.keys.flat_map { |code| [native_wmf_escape(code, "ab".b), native_wmf_escape(code, "abc".b)] }
  end

  def mismatched_escape_wire
    [native_wmf_escape(0x000A, "x".b * 259), native_wmf_escape(0x000A, "x".b * 260), native_wmf_escape(0x7777, "ab".b),
     native_wmf_escape(0x0015, "\0\0".b), native_wmf_escape(0x0011, "\x03\0\0".b), native_wmf_escape(0x0001, "x".b * 2)]
  end

  def passthrough_escape_wire
    [[[0xAABBCCDD, 3].pack("Vv") + "xyz".b, "\0".b], [[1, 4].pack("Vv") + "xyz".b, "\0".b],
     [[1, 2].pack("Vv") + "xyz".b, "\0".b], ["\0\0\0".b, "\0".b], [[7, 2].pack("Vv") + "ab".b, "".b]]
      .map { |data, padding| native_wmf_escape(0x11D8, data, padding: padding) }
  end

  def embedded_segment_wire
    stream = "EMFDATA".b * 3
    good = embedded_escapes(stream, 8).map { |record| wire_escape(record) }
    broken = [{ identifier: 1 }, { type: 2 }, { flags: 1 }, { count: 0 }, { current: 9000 }, { remaining: 5, total: 1 }]
             .map { |override| wire_escape(embedded_escape(embedded_segment_data("abcd".b, count: 1, total: 4, remaining: 0, **override))) }
    short = wire_escape(embedded_escape("short".b, padding: 0))
    good + broken + [short]
  end
end
