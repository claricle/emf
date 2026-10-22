# frozen_string_literal: true

require_relative "crafted_emf"

module Emf
  module SpecSupport
    # Crafted EMR_HEADER (with HeaderExtension1) and EMR_EOF records for the
    # control-buffer rules. Header layout: nDescription 60, offDescription 64,
    # nPalEntries 68, cbPixelFormat 88, offPixelFormat 92.
    module ControlBuffersCases
      module_function

      FIXED = 100
      GOOD_PFD = [40, 1, 0x25, 0].pack("vvVC") + ("\0".b * 31)

      def utf16(text) = text.encode(Encoding::UTF_16LE).b

      # Header record with the description and pixel format placed after the 100-byte
      # fixed part. Offsets and counts default to the real placement; override to corrupt.
      def header(description: utf16("emf\0"), pixel_format: GOOD_PFD, n_description: nil, off_description: nil,
                 cb_pixel_format: nil, off_pixel_format: nil, n_pal_entries: 2, total_extra: 0)
        desc_off = FIXED
        pfd_off = desc_off + description.bytesize
        body = description + pixel_format
        size = FIXED + body.bytesize + total_extra
        fixed = CraftedEmf.header(n_bytes: 0, n_records: 2, size: size, n_description: n_description || (description.bytesize / 2),
                                  off_description: off_description || desc_off).b
        fixed[68, 4] = [n_pal_entries].pack("V")
        fixed[88, 8] = [cb_pixel_format || pixel_format.bytesize, off_pixel_format || pfd_off].pack("V2")
        (fixed[0, FIXED] + body).ljust(size, "\0".b)
      end

      # EMR_EOF with an explicit palette placement.
      def eof(entries: 2, palette: "\xFF\x00\x00\x00".b * entries, count: nil, offset: 16, pad: 0)
        size = 20 + palette.bytesize + pad
        [14, size, count || entries, offset].pack("V4") + palette + ("\0".b * pad) + [size].pack("V")
      end

      def file(header: self.header, eof: self.eof)
        bytes = header + eof
        bytes[48, 4] = [bytes.bytesize].pack("V")
        bytes
      end

      # id => [crafted bytes]; each fires only its own rule.
      def cases
        {
          "emf.header.description_terminator" => file(header: header(description: utf16("emf!"))),
          "emf.header.buffers_overlap" => file(header: header(n_description: 10)),
          "emf.header.pixel_format_size" => file(header: header(cb_pixel_format: 44)),
          "emf.header.pixel_format_content" => file(header: header(pixel_format: [41, 2, 0x11, 3].pack("vvVC") + ("\0".b * 31))),
          "emf.eof.palette_entries" => file(header: header(n_pal_entries: 3)),
          "emf.eof.palette_bounds" => file(header: header(n_pal_entries: 9), eof: eof(count: 9))
        }
      end
    end
  end
end
