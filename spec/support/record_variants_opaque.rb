# frozen_string_literal: true

require_relative "record_variants"

# Variants for body-backed records whose Ruby wire keeps the bytes after the
# 8-byte header in `body` and exposes typed accessors over them: escapes, GLS,
# pixel format, UFI, color-management and colorspace records (MS-EMF 2.3.5.x
# escapes, 2.3.8 / 2.3.11 color records). Each variant supplies the body bytes
# and the accessor values those bytes must produce on both backends.
module RecordVariants
  self.catalog = :opaque
  TAIL = "\xDE\xAD\xBE\xEF".b.freeze
  NAME_A = "icc.pro\0".b.freeze
  NAME_W = "i\0c\0c\0\0\0".b.freeze
  ICC_DATA = (1..9).to_a.pack("C*").freeze
  PIXEL_FIELDS = [
    ["pfd_size", "v", 40], ["pfd_version", "v", 1], ["dw_flags", "V", 0x25], ["i_pixel_type", "C", 1], ["c_color_bits", "C", 32],
    ["c_red_bits", "C", 8], ["c_red_shift", "C", 16], ["c_green_bits", "C", 8], ["c_green_shift", "C", 8], ["c_blue_bits", "C", 8],
    ["c_blue_shift", "C", 0], ["c_alpha_bits", "C", 8], ["c_alpha_shift", "C", 24], ["c_accum_bits", "C", 64],
    ["c_accum_red_bits", "C", 16], ["c_accum_green_bits", "C", 16], ["c_accum_blue_bits", "C", 16], ["c_accum_alpha_bits", "C", 16],
    ["c_depth_bits", "C", 24], ["c_stencil_bits", "C", 8], ["c_aux_buffers", "C", 2], ["i_layer_type", "C", 0xFF],
    ["b_reserved", "C", 7], ["dw_layer_mask", "V", 0x01020304], ["dw_visible_mask", "V", UINT_MAX], ["dw_damage_mask", "V", 0]
  ].freeze
  # [name, byte offset, pack format, value] for the 12 COLORADJUSTMENT fields.
  ADJUSTMENT_FIELDS = [
    ["adjustment_size", "v", 24], ["values", "v", 3], ["illuminant_index", "v", 2], ["red_gamma", "v", 10_000],
    ["green_gamma", "v", 65_535], ["blue_gamma", "v", 0], ["reference_black", "v", 300], ["reference_white", "v", 9500],
    ["contrast", "s<", -100], ["brightness", "s<", 100], ["colorfulness", "s<", -32_768], ["red_green_tint", "s<", 32_767]
  ].freeze

  module OpaqueBuilders
    def body(bytes, *checks) = [raw("body", bytes), *checks]
    def le32(value) = [value].pack("V")
    def sized(count, bytes) = [count].pack("V") + bytes

    def escape_cases
      valid("no data", body([0x1A, 0].pack("V2"), check("i_escape", 0x1A), check("cj_in", 0), check("data_bytes", "")))
      valid("data then trailing bytes", body("#{[UINT_MAX, 5].pack('V2')}hello#{"\0\0\0".b}#{TAIL}",
                                             check("i_escape", UINT_MAX), check("cj_in", 5), check("data_bytes", "hello")))
      valid("aligned data", body("#{[4120, 8].pack('V2')}abcdefgh", check("i_escape", 4120), check("cj_in", 8),
                                 check("data_bytes", "abcdefgh")))
      malformed("data length exceeds record", raw("body", "#{[1, 4096].pack('V2')}xx"))
      malformed("body shorter than prefix", raw("body", [1].pack("V")))
    end

    def profile_cases(name, prefix_pack, prefix_checks)
      valid("name and profile", profile_body(name, ICC_DATA, prefix_pack, prefix_checks))
      valid("empty name and profile", profile_body("".b, "".b, prefix_pack, prefix_checks))
      valid("profile then trailing bytes", profile_body(name, ICC_DATA + TAIL, prefix_pack, prefix_checks, data_size: ICC_DATA.bytesize,
                                                                                                           keep_tail: true))
      malformed("name length exceeds record", raw("body", prefix_pack.call(7, 0xFFFF, 0) + name))
      malformed("profile length exceeds record", raw("body", "#{prefix_pack.call(7, name.bytesize, 0xFFFF)}#{name}xx"))
    end

    def profile_body(name, data, prefix_pack, prefix_checks, data_size: nil, keep_tail: false)
      size = data_size || data.bytesize
      prefix = prefix_pack.call(0x11, name.bytesize, size)
      body(prefix + name + data, *prefix_checks.call(0x11, name.bytesize, size), check("name_bytes", name),
           check("profile_bytes", keep_tail ? data.byteslice(0, size) : data))
    end
  end
  Entry.include(OpaqueBuilders)

  { "DrawEscape" => 105, "ExtEscape" => 106 }.each do |name, type|
    define(name, type) { escape_cases }
  end

  define("NamedEscape", 110) do
    driver = "DRV\0".b
    named = lambda do |escape, driver_bytes, data, tail = "".b|
      body([escape, driver_bytes.bytesize, data.bytesize].pack("V3") + driver_bytes + data + tail, check("i_escape", escape),
           check("cj_driver", driver_bytes.bytesize), check("cj_in", data.bytesize), check("driver_name_bytes", driver_bytes),
           check("data_bytes", data))
    end
    valid("driver and data", named.call(0x10, driver, "payload"))
    valid("empty driver and data", named.call(0, "".b, "".b))
    valid("max escape with trailing bytes", named.call(UINT_MAX, driver, "xyz", TAIL))
    malformed("driver length exceeds record", raw("body", [1, 0xFFFF, 0].pack("V3")))
    malformed("data length exceeds record", raw("body", [1, 0, 0xFFFF].pack("V3")))
  end

  define("GlsRecord", 102) do
    valid("no data", body(sized(0, "".b), check("cb_data", 0), check("data_bytes", "")))
    valid("data", body(sized(6, "glsabc"), check("cb_data", 6), check("data_bytes", "glsabc")))
    valid("data then trailing bytes", body(sized(2, "ab#{TAIL}"), check("cb_data", 2), check("data_bytes", "ab")))
    malformed("data length exceeds record", raw("body", sized(4096, "xx")))
  end

  define("GlsBoundedRecord", 103) do
    bounds = [-1, -2, 30, 40].pack("l<4")
    valid("no data", body(bounds + sized(0, "".b), check("bounds", bounds), check("cb_data", 0), check("data_bytes", "")))
    valid("data", body(bounds + sized(6, "glsabc"), check("bounds", bounds), check("cb_data", 6), check("data_bytes", "glsabc")))
    valid("data then trailing bytes", body(bounds + sized(2, "ab#{TAIL}"), check("cb_data", 2), check("data_bytes", "ab")))
    malformed("data length exceeds record", raw("body", bounds + sized(4096, "xx")))
    malformed("body shorter than bounds", raw("body", "\0".b * 12))
  end

  define("PixelFormat", 104) do
    pfd = PIXEL_FIELDS.map { |_, format, value| [value].pack(format) }.join.b
    checks = PIXEL_FIELDS.map { |field, _, value| check(field, value) }
    valid("all 26 fields", body(pfd, *checks, check("pfd_bytes", pfd)))
    valid("zero descriptor", body("\0".b * 40, check("pfd_size", 0), check("dw_damage_mask", 0), check("pfd_bytes", "\0".b * 40)))
    valid("descriptor then trailing bytes", body(pfd + TAIL, *checks, check("pfd_bytes", pfd)))
    malformed("body shorter than descriptor", raw("body", pfd.byteslice(0, 39)))
  end

  define("ForceUfiMapping", 109) do
    ufi = [0x8000_0001, UINT_MAX].pack("V2")
    valid("checksum and index", body(ufi, check("ufi_checksum", 0x8000_0001), check("ufi_index", UINT_MAX), check("ufi_bytes", ufi)))
    valid("zero", body("\0".b * 8, check("ufi_checksum", 0), check("ufi_index", 0)))
    valid("trailing bytes", body(ufi + TAIL, check("ufi_checksum", 0x8000_0001), check("ufi_bytes", ufi)))
    malformed("body shorter than UFI", raw("body", "\1".b * 7))
  end

  define("SetLinkedUfis", 119) do
    first = [0x8000_0001, UINT_MAX].pack("V2")
    second = [0x1234_5678, 0x8765_4321].pack("V2")
    reserved = "reserved".b
    valid("no entries", body(sized(0, reserved), check("u_num_linked_ufi", 0)))
    valid("two entries", body(sized(2, first + second + reserved), check("u_num_linked_ufi", 2), check("ufi_checksum(0)", 0x8000_0001),
                              check("ufi_index(0)", UINT_MAX), check("ufi_bytes(1)", second), check("ufi_checksum(1)", 0x1234_5678)))
    valid("entries then trailing bytes", body(sized(1, first + reserved + TAIL), check("u_num_linked_ufi", 1),
                                              check("ufi_bytes(0)", first)))
    malformed("count exceeds record", raw("body", sized(UINT_MAX, reserved)))
    malformed("array without reserved bytes", raw("body", sized(1, first)))
  end

  define("ColorCorrectPalette", 111) do
    valid("handle and entries", body([3, 1, 256, 0].pack("V4"), check("ih_palette", 3), check("first_entry", 1),
                                     check("entry_count", 256), check("reserved", 0)))
    valid("max values", body(([UINT_MAX] * 4).pack("V4"), check("ih_palette", UINT_MAX), check("entry_count", UINT_MAX),
                             check("reserved", UINT_MAX)))
    valid("trailing bytes", body([1, 2, 3, 4].pack("V4") + TAIL, check("first_entry", 2), check("reserved", 4)))
    malformed("body shorter than fields", raw("body", "\0".b * 15))
  end

  define("SetColorAdjustment", 23) do
    adjustment = ADJUSTMENT_FIELDS.map { |_, format, value| [value].pack(format) }.join.b
    checks = ADJUSTMENT_FIELDS.map { |field, _, value| check(field, value) }
    valid("all 12 fields", body(adjustment, *checks))
    valid("zero adjustment", body("\0".b * 24, check("adjustment_size", 0), check("contrast", 0), check("red_green_tint", 0)))
    valid("fields then trailing bytes", body(adjustment + TAIL, *checks))
    malformed("body shorter than adjustment", raw("body", adjustment.byteslice(0, 23)))
  end

  { "SetColorspace" => 100, "DeleteColorspace" => 101 }.each do |name, type|
    define(name, type) do
      valid("handle", body(le32(7), check("ih_cs", 7)))
      valid("max handle", body(le32(UINT_MAX), check("ih_cs", UINT_MAX)))
      valid("handle then trailing bytes", body("#{le32(9)}#{TAIL}", check("ih_cs", 9)))
      malformed("body shorter than handle", raw("body", "\0".b * 3))
    end
  end

  space = lambda do |filename_bytes|
    endpoints = (1..9).flat_map { |n| [n * 100, n * 1000, UINT_MAX - n] }.first(9).pack("V9")
    [0x5053_4F43, 0x400, 328 + (filename_bytes.bytesize - 260), 0, 8].pack("V3l<2") + endpoints + [0x10000, 0x20000, 0x30000].pack("V3") +
      filename_bytes
  end
  space_checks = lambda do
    Fields.check("lcs_signature",
                 0x5053_4F43) + Fields.check("lcs_version", 0x400) + Fields.check("color_space_type", 0) + Fields.check("intent", 8) +
      Fields.check("gamma_red", 0x10000) + Fields.check("gamma_green", 0x20000) + Fields.check("gamma_blue", 0x30000)
  end

  define("CreateColorspace", 99) do
    file = ("C:\\profile.icm\0".b + ("\0".b * 245))
    valid("calibrated RGB", body([5].pack("V") + space.call(file), check("ih_cs", 5), *space_checks.call,
                                 check("filename_bytes", file)))
    valid("negative type and intent", body([6].pack("V") + space.call(file).tap { |b| b[12, 8] = [-1, -2].pack("l<2") },
                                           check("ih_cs", 6), check("color_space_type", -1), check("intent", -2)))
    valid("trailing bytes", body([5].pack("V") + space.call(file) + TAIL, check("ih_cs", 5), check("filename_bytes", file)))
    malformed("body shorter than LOGCOLORSPACE", raw("body", "\0".b * 331))
  end

  define("CreateColorspaceW", 122) do
    file = ("p\0".b * 10) + ("\0".b * 500)
    wide = lambda do |data, flags = 1|
      [5].pack("V") + space.call(file) + [flags, data.bytesize].pack("V2") + data
    end
    valid("no profile data", body(wide.call("".b), check("ih_cs", 5), *space_checks.call, check("dw_flags", 1), check("cb_data", 0),
                                  check("profile_bytes", "")))
    valid("embedded profile", body(wide.call(ICC_DATA, 0xFFFF_FFFF), check("filename_bytes", file), check("dw_flags", UINT_MAX),
                                   check("cb_data", 9), check("profile_bytes", ICC_DATA)))
    valid("profile then trailing bytes", body(wide.call(ICC_DATA) + TAIL, check("cb_data", 9), check("profile_bytes", ICC_DATA)))
    malformed("profile length exceeds record", raw("body", wide.call("".b).tap { |b| b[596, 4] = [4096].pack("V") }))
    malformed("body shorter than flags", raw("body", [5].pack("V") + space.call(file)))
  end

  define("SetIcmProfileA", 112) do
    profile_cases(NAME_A, ->(flags, name, data) { [flags, name, data].pack("V3") },
                  ->(flags, name, data) { check("dw_flags", flags) + check("cb_name", name) + check("cb_data", data) })
  end

  define("SetIcmProfileW", 113) do
    profile_cases(NAME_W, ->(flags, name, data) { [flags, name, data].pack("V3") },
                  ->(flags, name, data) { check("dw_flags", flags) + check("cb_name", name) + check("cb_data", data) })
  end

  define("ColorMatchToTargetW", 121) do
    pack = ->(action, name, data) { [action, 0x22, name, data].pack("V4") }
    checks = lambda { |action, name, data|
      check("dw_action", action) + check("dw_flags", 0x22) + check("cb_name", name) + check("cb_data", data)
    }
    profile_cases(NAME_W, pack, checks)
  end
end
