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
        :color_table_offset, :color_table_entries, :color_table_bytes,
        keyword_init: true
      )
        # header is nil whenever reason is set.
        View = Struct.new(:header, :reason) do
          def valid?
            !header.nil?
          end
        end

        KINDS = { 12 => :core, 40 => :info, 108 => :v4, 124 => :v5 }.freeze
        BI_BITFIELDS = 3
        BI_ALPHABITFIELDS = 6
        private_constant :KINDS, :BI_BITFIELDS, :BI_ALPHABITFIELDS

        # offset/size are the record's offBmi/cbBmi (from record start);
        # fixed is the byte length of the declared fixed part including the
        # 8-byte EMR header; tail is the opaque remainder after it.
        def self.view(offset, size, fixed, tail)
          offset = offset.to_i
          size = size.to_i
          tail = tail.to_s
          return View.new(nil, :absent) if size.zero?
          return View.new(nil, :offset_in_fixed_part) if offset < fixed

          start = offset - fixed
          return View.new(nil, :past_record) if start + size > tail.bytesize

          build(tail.byteslice(start, size))
        end

        def self.build(bmi)
          return View.new(nil, :truncated) if bmi.bytesize < 4

          header_size = bmi.unpack1("V")
          kind = KINDS[header_size]
          return View.new(nil, :unsupported_header_size) unless kind
          return View.new(nil, :bmi_smaller_than_header) if bmi.bytesize < header_size

          header = kind == :core ? core(bmi) : info(bmi, kind)
          header.color_table_bytes <= bmi.bytesize - header_size ? View.new(header, nil) : View.new(nil, :color_table_past_bmi)
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
          entries = table_entries(kind, bit_count, compression, used)
          new(kind: kind, header_size: header_size, width: width, height: height, planes: planes, bit_count: bit_count,
              compression: compression, size_image: size_image, x_pels_per_meter: xppm, y_pels_per_meter: yppm,
              clr_used: used, clr_important: important, color_table_offset: header_size,
              color_table_entries: entries, color_table_bytes: entries * entry_size)
        end

        # A BITMAPINFOHEADER with BI_BITFIELDS/BI_ALPHABITFIELDS stores the
        # channel masks where the colour table would start.
        def self.table_entries(kind, bit_count, compression, used)
          return 3 if kind == :info && compression == BI_BITFIELDS
          return 4 if kind == :info && compression == BI_ALPHABITFIELDS
          return used if bit_count > 8

          used.zero? ? 1 << bit_count : used
        end

        private_class_method :build, :core, :info, :make, :table_entries
      end
    end
  end
end
