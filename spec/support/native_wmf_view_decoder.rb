# frozen_string_literal: true

require "emf/wmf"

# Decodes the WMFV/WMFE transports into the Ruby view structs. Escape kind names come from the
# Ruby tables; the Rust side contributes the subtype code.
class NativeWmfViewDecoder
  ERRORS = %i[not_embedded_emf transport metadata comment_identifier comment_type non_zero_flags zero_record_count
              segment_too_large inconsistent_sizes sequence_mismatch remaining_mismatch record_count_mismatch incomplete
              limit_exceeded].freeze

  class Reader
    def initialize(bytes)
      @bytes = bytes
      @position = 0
    end

    def take(length)
      raise "truncated view" if length > @bytes.bytesize - @position

      @bytes.byteslice(@position, length).tap { @position += length }
    end

    def u32 = take(4).unpack1("V")
    def i32 = take(4).unpack1("l<")
    def u64 = take(8).unpack1("Q<")
    def bytes = take(u64)
    def finished? = @position == @bytes.bytesize
  end

  def record(bytes)
    reader = Reader.new(bytes)
    raise "bad WMFV header" unless reader.take(4) == "WMFV" && reader.u32 == 1

    views = Array.new(reader.u32) { decode_entry(reader) }
    raise "unconsumed WMFV bytes" unless reader.finished?

    views
  end

  def sequences(bytes)
    reader = Reader.new(bytes)
    raise "bad WMFE header" unless reader.take(4) == "WMFE" && reader.u32 == 1

    sequences = Array.new(reader.u64) do
      first = reader.u64
      count = reader.u64
      if reader.u32 == 1
        stream = Emf::Wmf::EmbeddedEmf::Stream.new(version: reader.u32, checksum: reader.u32, checksum_valid: reader.u32 == 1,
                                                   bytes: reader.bytes)
        Emf::Wmf::EmbeddedEmf::Sequence.new(first_record: first, segment_count: count, stream: stream, error: nil)
      else
        Emf::Wmf::EmbeddedEmf::Sequence.new(first_record: first, segment_count: count, stream: nil,
                                            error: ERRORS.fetch(reader.u32 - 1))
      end
    end
    raise "unconsumed WMFE bytes" unless reader.finished?

    sequences
  end

  private

  def decode_entry(reader)
    case (tag = reader.u32)
    when 1 then Emf::Wmf::BitmapImage::ABSENT
    when 2 then decode_bitmap16(reader)
    when 3 then decode_dib(reader)
    when 4 then decode_fixed(reader)
    when 5 then decode_counted(reader)
    when 6 then Emf::Wmf::EscapeViews::SpecialPassthrough2.new(reserved: reader.u32, data: reader.bytes)
    when 7 then decode_segment(reader)
    when 8 then ERRORS.fetch(reader.u32 - 1)
    else raise "unknown view tag #{tag}"
    end
  end

  def decode_bitmap16(reader)
    type, width, height, width_bytes = Array.new(4) { reader.i32 }
    Emf::Wmf::Bitmap16::Image.new(bitmap_type: type, width: width, height: height, width_bytes: width_bytes,
                                  planes: reader.u32, bits_pixel: reader.u32, pixels: reader.bytes, trailing: reader.bytes)
  end

  def decode_dib(reader)
    header = reader.u32.zero? ? decode_core(reader) : decode_info(reader)
    masked = reader.u32 == 1
    masks = Array.new(3) { reader.u32 }
    Emf::Wmf::Dib::Image.new(header: header, bitfield_masks: masked ? masks : nil, colors: decode_colors(reader),
                             pixels: reader.bytes, trailing: reader.bytes)
  end

  def decode_core(reader)
    width, height, planes, bits = Array.new(4) { reader.u32 }
    Emf::Wmf::Dib::CoreHeader.new(width: width, height: height, planes: planes, bit_count: bits)
  end

  def decode_info(reader)
    width = reader.i32
    height = reader.i32
    planes, bits, compression, image_size = Array.new(4) { reader.u32 }
    x_pels = reader.i32
    y_pels = reader.i32
    used = reader.u32
    important = reader.u32
    Emf::Wmf::Dib::InfoHeader.new(width: width, height: height, planes: planes, bit_count: bits, compression: compression,
                                  image_size: image_size, x_pels_per_meter: x_pels, y_pels_per_meter: y_pels,
                                  colors_used: used, colors_important: important, extension: reader.bytes)
  end

  def decode_colors(reader)
    kind = reader.u32
    count = reader.u64
    case kind
    when 0 then Emf::Wmf::Dib::ColorTable.new(kind: :none, rows: [])
    when 1 then Emf::Wmf::Dib::ColorTable.new(kind: :rgb_triples, rows: Array.new(count) { reader.take(3).bytes })
    when 2 then Emf::Wmf::Dib::ColorTable.new(kind: :rgb_quads, rows: Array.new(count) { reader.take(4).bytes })
    else Emf::Wmf::Dib::ColorTable.new(kind: :palette_indices, rows: Array.new(count) { reader.take(2).unpack1("v") })
    end
  end

  def decode_fixed(reader)
    code = reader.u32
    values = Array.new(reader.u64) { reader.take(8).unpack1("q<") }
    kind, _length, _format, names = Emf::Wmf::EscapeViews::FIXED[code]
    return Emf::Wmf::EscapeViews::Payload.new(kind: Emf::Wmf::EscapeViews::EMPTY.fetch(code), fields: {}) unless kind

    Emf::Wmf::EscapeViews::Payload.new(kind: kind, fields: names.zip(values).to_h)
  end

  def decode_counted(reader)
    code = reader.u32
    Emf::Wmf::EscapeViews::CountedPayload.new(kind: Emf::Wmf::EscapeViews::COUNTED.fetch(code), data: reader.bytes)
  end

  def decode_segment(reader)
    version, checksum, flags, count, current, remaining, total = Array.new(7) { reader.u32 }
    Emf::Wmf::EmbeddedEmf::Segment.new(version: version, checksum: checksum, flags: flags, record_count: count,
                                       current_size: current, remaining_bytes: remaining, total_size: total,
                                       data: reader.bytes)
  end
end
