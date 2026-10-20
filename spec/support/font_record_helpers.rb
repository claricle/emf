# frozen_string_literal: true

module FontRecordHelpers
  def font_record_bytes(body)
    [82, body.bytesize + 12, 7].pack("V3") + body
  end

  def log_font_bytes
    [-18, -2, 900, -900, 700].pack("l<5") + [1, 2, 3, 255, 4, 5, 6, 0x31].pack("C8") +
      ([0xD800, 0, 0xDC00] + Array.new(29, 65)).pack("v32")
  end

  def panose_font_bytes
    log_font_bytes + Array.new(64, 66).pack("v64") + Array.new(32, 67).pack("v32") +
      [2, 3, 4, 5, 0x44434241, 6].pack("V6") + (1..12).to_a.pack("C12")
  end

  def exdv_font_bytes(axes = [-123, 456], suffix = "\xAA\xBB\xCC\xDD".b)
    log_font_bytes + Array.new(64, 66).pack("v64") + Array.new(32, 67).pack("v32") +
      Array.new(32, 68).pack("v32") + [0x08007664, axes.length].pack("V2") + axes.pack("l<*") + suffix
  end
end
