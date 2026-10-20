# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Read-only typed view of the DIB header (BITMAPCOREHEADER,
      # BITMAPINFOHEADER, BITMAPV4HEADER, BITMAPV5HEADER) embedded in an EMR
      # bitmap record, plus the bounds of its colour table. The record bytes
      # are never touched; a malformed record yields a view with no header and
      # a reason instead of raising.
      class DibHeader < Struct.new(
        :kind, :header_size, :width, :height, :planes, :bit_count, :compression, :size_image,
        :x_pels_per_meter, :y_pels_per_meter, :clr_used, :clr_important,
        :bitfield_mask_count, :color_table_offset, :color_table_entries, :color_table_bytes,
        keyword_init: true
      )
        # header is nil whenever reason is set. The pixel array is judged
        # separately so a header problem is never masked: bits_reason is nil
        # when the header is unusable (the stride needs it) or the bits are
        # sound, and valid? keeps meaning "the header is usable".
        View = Struct.new(:header, :reason, :bits_offset, :bits_size, :bits_reason) do
          def valid?
            !header.nil?
          end

          def bits_valid?
            valid? && bits_reason.nil?
          end
        end

        KINDS = { 12 => :core, 40 => :info, 108 => :v4, 124 => :v5 }.freeze
        BI_RGB = 0
        BI_BITFIELDS = 3
        BI_ALPHABITFIELDS = 6
        BI_JPEG = 4
        BI_PNG = 5
        UNCOMPRESSED = [BI_RGB, BI_BITFIELDS, BI_ALPHABITFIELDS].freeze
        private_constant :KINDS, :BI_RGB, :BI_BITFIELDS, :BI_ALPHABITFIELDS, :BI_JPEG, :BI_PNG, :UNCOMPRESSED

        # offset/size are the record's offBmi/cbBmi (from record start);
        # fixed is the byte length of the declared fixed part including the
        # 8-byte EMR header; tail is the opaque remainder after it.
        # bits_offset/bits_size are the record's offBits/cbBits.
        def self.view(offset, size, fixed, tail, bits_offset: 0, bits_size: 0)
          offset = offset.to_i
          size = size.to_i
          tail = tail.to_s
          bits = [bits_offset.to_i, bits_size.to_i]
          return View.new(nil, :absent, *bits) if size.zero?
          return View.new(nil, :offset_in_fixed_part, *bits) if offset < fixed

          start = offset - fixed
          return View.new(nil, :past_record, *bits) if start + size > tail.bytesize

          with_bits(build(tail.byteslice(start, size)), offset, size, fixed, tail.bytesize, bits)
        end

        def self.with_bits(view, offset, size, fixed, tail_size, bits)
          view.bits_offset, view.bits_size = bits
          view.bits_reason = bits_reason(view.header, offset, size, fixed, tail_size, bits) if view.valid?
          view
        end

        def self.bits_reason(header, offset, size, fixed, tail_size, bits)
          bits_offset, bits_size = bits
          return :bits_absent if bits_size.zero?
          return :bits_in_fixed_part if bits_offset < fixed
          return :bits_past_record if bits_offset - fixed + bits_size > tail_size
          return :bits_overlap_bmi if bits_offset < offset + size && offset < bits_offset + bits_size

          :bits_smaller_than_image if bits_size < minimum_bits(header)
        end

        # Only uncompressed rows have a stride-derived minimum. RLE4/RLE8 runs
        # can be far shorter than stride * height, and for BI_JPEG/BI_PNG
        # (MS-WMF 2.2.2.3 BitmapInfoHeader) the pixel array is the encoded
        # image, so bit_count does not describe it.
        def self.minimum_bits(header)
          return 0 unless UNCOMPRESSED.include?(header.compression)

          (((header.width.abs * header.bit_count) + 31) / 32) * 4 * header.height.abs
        end

        def self.build(bmi)
          return View.new(nil, :truncated) if bmi.bytesize < 4

          header_size = bmi.unpack1("V")
          kind = KINDS[header_size]
          return View.new(nil, :unsupported_header_size) unless kind
          return View.new(nil, :bmi_smaller_than_header) if bmi.bytesize < header_size

          header = kind == :core ? core(bmi) : info(bmi, kind)
          fits = header.color_table_offset + header.color_table_bytes <= bmi.bytesize
          fits ? View.new(header, nil) : View.new(nil, :color_table_past_bmi)
        end

        def self.core(bmi)
          width, height, planes, bit_count = bmi.unpack("x4v4")
          make(:core, 12, width, height, planes, bit_count, 0, 0, 0, 0, 0, 0, 3)
        end

        def self.info(bmi, kind)
          width, height, planes, bit_count, compression, size_image, xppm, yppm, clr_used, clr_important = bmi.unpack("x4l<2v2V2l<2V2")
          make(kind, KINDS.key(kind), width, height, planes, bit_count, compression, size_image, xppm, yppm, clr_used, clr_important, 4)
        end

        def self.make(kind, header_size, width, height, planes, bit_count, compression, size_image, xppm, yppm, used, important, entry_size)
          masks = mask_count(kind, compression)
          entries = table_entries(kind, bit_count, compression, used)
          new(kind: kind, header_size: header_size, width: width, height: height, planes: planes, bit_count: bit_count,
              compression: compression, size_image: size_image, x_pels_per_meter: xppm, y_pels_per_meter: yppm,
              clr_used: used, clr_important: important, bitfield_mask_count: masks,
              color_table_offset: header_size + (masks * 4),
              color_table_entries: entries, color_table_bytes: entries * entry_size)
        end

        # A BITMAPINFOHEADER with BI_BITFIELDS/BI_ALPHABITFIELDS stores the
        # channel masks between the header and the colour table; V4/V5
        # headers carry them inside the header itself.
        def self.mask_count(kind, compression)
          return 0 unless kind == :info

          { BI_BITFIELDS => 3, BI_ALPHABITFIELDS => 4 }.fetch(compression, 0)
        end

        def self.table_entries(kind, bit_count, compression, used)
          return 0 if kind == :info && compressed_image?(compression)
          return used if bit_count > 8

          used.zero? ? 1 << bit_count : used
        end

        def self.compressed_image?(compression)
          [BI_JPEG, BI_PNG].include?(compression)
        end

        private_class_method :with_bits, :bits_reason, :minimum_bits, :compressed_image?, :build, :core, :info, :make,
                             :mask_count, :table_entries
      end
    end
  end
end
