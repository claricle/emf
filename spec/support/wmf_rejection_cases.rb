# frozen_string_literal: true

# One crafted WMF input per rejection reason the native backend reports, keyed by reason code. Reasons that need
# a 200 MiB input (101) or a million records (401) are covered by the Rust tests instead. Reasons 203, 406, 1003 and
# 1702 are retired (recovered, see WmfRecovery), so they have no case.
module WmfRejectionCases
  module_function

  def rec(function, body = "".b)
    [(6 + body.bytesize) / 2, function].pack("Vv") + body
  end

  def words(*values)
    values.pack("v*")
  end

  def eof
    rec(0)
  end

  def header(size_words, objects: 0, max: 3)
    [1, 9, 0x300, size_words, objects, max, 0].pack("v3VvVv")
  end

  def wmf(records, objects: 0)
    body = records.join
    header(9 + (body.bytesize / 2), objects: objects, max: records.map { |r| r.bytesize / 2 }.max) + body
  end

  def placeable(reserved: 0, checksum: nil, handle: 0)
    head = [0x9AC6CDD7, handle, 0, 0, 100, 100, 96, reserved].pack("Vvs<4vV")
    head + [checksum || head.unpack("v10").reduce(0, :^)].pack("v")
  end

  def region(count, size, max, scan)
    words(0, 6, 0, 0, size, count, max, 0, 0, 0, 0) + words(*scan)
  end

  def alone(function, body)
    wmf([rec(function, body), eof])
  end

  def object_world(objects, *records)
    wmf([*records, eof], objects: objects)
  end

  def cases
    @cases ||= {}.merge(phase, framing, payload, object_table).freeze
  end

  def phase
    plain = wmf([eof])
    tweak = ->(at, value) { plain.dup.tap { |bytes| bytes.setbyte(at, value) } }
    { 201 => "\xD7\xCD\xC6\x9A\x01\x02\x03".b, 202 => placeable(reserved: 1) + plain,
      301 => "\x01\x00\x09\x00\x00\x03".b, 302 => tweak.call(0, 3),
      303 => tweak.call(2, 8), 304 => tweak.call(5, 2),
      306 => placeable(handle: 7) + tweak.call(0, 2) }
  end

  def framing
    bad_length = wmf([eof]).tap { |bytes| bytes.setbyte(18, 2) }
    { 402 => header(11) + "\0\0\0\0".b, 403 => bad_length, 405 => wmf([rec(0x1E)]) }
  end

  def payload
    { 501 => alone(0x14, words(0, 0, 0, 0)), 601 => alone(0x01, words(0)), 701 => alone(0xFB, "\0".b * 10),
      801 => alone(0x2D, "".b) }.merge(points, text, palette_region, brush_bitmap, geometry_escape)
  end

  def points
    { 901 => alone(0x25, "".b), 902 => alone(0x38, words(5, 0)), 903 => alone(0x24, words(1, 0, 0)),
      904 => alone(0x25, words(2, 0, 0)) }
  end

  def text
    { 1001 => alone(0x21, "\0".b * 4), 1002 => alone(0x32, words(0, 0, 0, 2)),
      1004 => alone(0x21, words(10, 0, 0)),
      1005 => alone(0x32, "#{words(0, 0, 4, 0)}abcd#{words(0)}") }
  end

  def palette_region
    { 1101 => alone(0xF7, words(0)), 1102 => alone(0xF7, words(0, 5)), 1201 => alone(0x28, words(0)),
      1202 => alone(0xFF, "\0".b * 10), 1203 => alone(0xFF, "\0".b * 22),
      1204 => alone(0xFF, region(2, 38, 4, [4, 0, 0, 0, 0, 0, 0, 4])),
      1205 => alone(0xFF, region(1, 30, 0, [1, 0, 0, 0])), 1206 => alone(0xFF, region(1, 30, 5, [0, 0, 0, 0])) }
  end

  def brush_bitmap
    { 1301 => alone(0xF9, "\0".b * 10), 1302 => alone(0xF9, "\0".b * 32), 1303 => alone(0x42, words(0)),
      1304 => alone(0x42, words(1, 5, 0)), 1401 => alone(0x22, "\0".b * 4), 1402 => alone(0x22, "\0".b * 16) }
  end

  def geometry_escape
    { 1501 => alone(0x10, words(0)), 1502 => alone(0x48, words(2, 0, 0, 0, 0)), 1601 => alone(0x27, "".b),
      1602 => alone(0x26, words(0)), 1603 => alone(0x26, words(1, 10)) }
  end

  def object_table
    pen = rec(0xFA, words(0, 0, 0, 0, 0))
    brush = rec(0xFC, words(0, 0, 0, 0))
    region = rec(0xFF, words(0, 6, 0, 0, 22, 0, 0, 0, 0, 0, 0))
    { 1701 => object_world(0, pen), 1703 => object_world(1, brush, rec(0x34, words(0))),
      1704 => object_world(2, brush, brush, rec(0x28, words(0, 1))),
      1705 => object_world(1, rec(0x28, words(0, 0))), 1706 => object_world(2, region, rec(0x28, words(0, 1))),
      1707 => object_world(2, region, pen, rec(0x28, words(0, 1))) }
  end
end
