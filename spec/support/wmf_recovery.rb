# frozen_string_literal: true

require_relative "native_wmf"

# Crafted WMF files with one record-level or placeable departure that Emf::Wmf::Recovery, the placeable reader and the
# object-table walk recover from, and the neighbouring shapes that stay rejected.
module WmfRecovery
  include NativeWmfSupport

  PEN_FIELDS = [1, 2, 3, 4, 5].pack("v5").freeze
  MOVE_TO = [5, 6].pack("s<2").freeze

  def line = native_wmf_record(0x0214, MOVE_TO)

  def eof_words(words) = [words, 0].pack("Vv") + ("\0".b * ((words - 3) * 2))

  # A whole file from raw records (which carry their own EOF); Size and MaxRecord are consistent with them.
  def stream(records, objects: 2, placeable: false)
    body = records.join
    header = [1, 9, 0x300, 9 + (body.bytesize / 2), objects, records.map { |record| record.bytesize / 2 }.max, 0].pack("v3VvVv")
    return header + body unless placeable

    prefix = [Emf::Wmf::Binary::PLACEABLE_KEY, 0, 0, 0, 100, 100, 96, 0].pack("Vvs<4vV")
    prefix + [Emf::Wmf::Binary.checksum(prefix)].pack("v") + header + body
  end

  def offset_of(records, index) = 18 + records.first(index).sum(&:bytesize)

  def font_record(face)
    fixed = [-12, 0, 0, 0, 400].pack("s<5") + [0, 0, 0, 1, 0, 0, 0, 0x22].pack("C8")
    native_wmf_record(0x02FB, fixed + face)
  end

  # name => { bytes:, types: record functions, check:, offset:, declared:, actual: } for one recovered departure.
  def cases
    eof5 = eof_words(5)
    pen = native_wmf_record(0x02FA, "#{PEN_FIELDS}xx")
    short_font = font_record("Arial\0".b)
    negative_ext = native_wmf_record(0x0A32, [0, 0, -3, 0].pack("s<3v"))
    negative_text = native_wmf_record(0x0521, [-1, 0, 0].pack("s<3"))
    delete = native_wmf_record(0x01F0, [5].pack("v"))
    clip = native_wmf_record(0x012C, [0].pack("v"))
    brush = native_wmf_record(0x02FC, [0, 0, 0, 0].pack("v4"))
    checksum_file = stream([line, eof_words(3)], placeable: true).tap { |bytes| bytes[20, 2] = [0xFFFF].pack("v") }
    {
      "EOF longer than three words" => { bytes: stream([line, eof5]), types: [0x0214, 0], check: :eof_length_invalid,
                                         offset: offset_of([line], 1), declared: 5, actual: 3 },
      "object record with surplus bytes" => { bytes: stream([pen, eof_words(3)]), types: [0x02FA, 0],
                                              check: :object_record_length_invalid, offset: 18, declared: 9, actual: 8 },
      "font shorter than its face name" => { bytes: stream([short_font, eof_words(3)]), types: [0x02FB, 0],
                                             check: :font_record_length_invalid, offset: 18, declared: 15, actual: 28 },
      "ExtTextOut with a negative length" => { bytes: stream([negative_ext, eof_words(3)]), types: [0x0A32, 0],
                                               check: :text_length_negative, offset: 18, declared: 7, actual: nil },
      "TextOut with a negative length" => { bytes: stream([negative_text, eof_words(3)]), types: [0x0521, 0],
                                            check: :text_length_negative, offset: 18, declared: 6, actual: nil },
      "DeleteObject of no live object" => { bytes: stream([delete, eof_words(3)], objects: 1), types: [0x01F0, 0],
                                            check: :object_reference_invalid, offset: 18, declared: 5, actual: 1 },
      "SelectClipRegion of a brush" => { bytes: stream([brush, clip, eof_words(3)], objects: 1), types: [0x02FC, 0x012C, 0],
                                         check: :object_reference_not_region, offset: 18 + brush.bytesize, declared: 0, actual: 1 },
      "placeable checksum mismatch" => { bytes: checksum_file, types: [0x0214, 0], check: :placeable_checksum_mismatch,
                                         offset: 20, declared: 0xFFFF, actual: Emf::Wmf::Binary.checksum(checksum_file) }
    }
  end

  # name => [bytes, rejection message pattern]: neighbouring shapes that cannot be framed safely and stay rejected.
  def rejected
    {
      "object record shorter than its payload" => [stream([native_wmf_record(0x02FA, "\0".b * 8), eof_words(3)]),
                                                   /invalid object record length at offset 18/],
      "font without its fixed fields" => [stream([native_wmf_record(0x02FB, "\0".b * 10), eof_words(3)]),
                                          /invalid font record length at offset 18/],
      "text record shorter than its header" => [stream([native_wmf_record(0x0521, "\0".b * 2), eof_words(3)]),
                                                /truncated text record at offset 18/],
      "FillRegion naming a brush" => [stream([native_wmf_record(0x02FC, [0, 0, 0, 0].pack("v4")),
                                              native_wmf_record(0x02FC, [0, 0, 0, 0].pack("v4")),
                                              native_wmf_record(0x0228, [0, 1].pack("v2")), eof_words(3)]),
                                      /object reference 0 is not a region at offset 46/],
      "SelectPalette of a brush" => [stream([native_wmf_record(0x02FC, [0, 0, 0, 0].pack("v4")),
                                             native_wmf_record(0x0234, [0].pack("v")), eof_words(3)], objects: 1),
                                     /object reference 0 is not a palette at offset 32/],
      "EOF declaring more words than the input holds" => [stream([line, eof_words(5)]).byteslice(0, 18 + 10 + 6),
                                                          /invalid record length 5 at offset 28/]
    }
  end
end
