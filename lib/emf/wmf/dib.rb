# frozen_string_literal: true

module Emf
  module Wmf
    # Read-only views of the packed bitmap interiors retained by WMF records.
    # The raw bytes on the record stay authoritative; compressed pixels, header
    # extensions and padding are kept verbatim and nothing is decoded or converted.
    # Malformed or unsupported layouts return nil, as in the Rust views.
    module Dib
      CoreHeader = Struct.new(:width, :height, :planes, :bit_count, keyword_init: true)
      InfoHeader = Struct.new(:width, :height, :planes, :bit_count, :compression, :image_size, :x_pels_per_meter,
                              :y_pels_per_meter, :colors_used, :colors_important, :extension, keyword_init: true)
      # kind is :none, :rgb_triples, :rgb_quads or :palette_indices.
      ColorTable = Struct.new(:kind, :rows, keyword_init: true)
      Image = Struct.new(:header, :bitfield_masks, :colors, :pixels, :trailing, keyword_init: true)
      Layout = Struct.new(:header, :masks, :color_count, :entry_size, :pixel_start, :pixel_size, keyword_init: true)

      COMPRESSIONS = [0, 1, 2, 3, 4, 5, 11, 12, 13].freeze
      BIT_COUNTS = [0, 1, 4, 8, 16, 24, 32].freeze
      RLE_BITS = { 1 => 8, 12 => 8, 2 => 4, 13 => 4 }.freeze
      PROFILE_SIGNATURES = [0x4C494E4B, 0x4D424544].freeze

      module_function

      def parse(bytes, color_usage = 0)
        bytes = bytes.b
        layout = layout(bytes, color_usage) or return
        header = layout.header
        Image.new(header: header_view(bytes, header),
                  bitfield_masks: layout.masks.positive? ? bytes.byteslice(header, 12).unpack("V3") : nil,
                  colors: color_table(bytes, layout, color_usage),
                  pixels: bytes.byteslice(layout.pixel_start, layout.pixel_size),
                  trailing: bytes.byteslice((layout.pixel_start + layout.pixel_size)..))
      end

      def header_view(bytes, size)
        if size == 12
          width, height, planes, bits = bytes.unpack("@4v4")
          return CoreHeader.new(width: width, height: height, planes: planes, bit_count: bits)
        end
        width, height, planes, bits, compression, image_size, x_pels, y_pels, used, important = bytes.unpack("@4l<2v2V2l<2V2")
        InfoHeader.new(width: width, height: height, planes: planes, bit_count: bits, compression: compression,
                       image_size: image_size, x_pels_per_meter: x_pels, y_pels_per_meter: y_pels, colors_used: used,
                       colors_important: important, extension: bytes.byteslice(40, size - 40))
      end

      def color_table(bytes, layout, color_usage)
        return ColorTable.new(kind: :none, rows: []) if color_usage == 2

        raw = bytes.byteslice(layout.header + layout.masks, layout.pixel_start - layout.header - layout.masks)
        case layout.entry_size
        when 2 then ColorTable.new(kind: :palette_indices, rows: raw.unpack("v*"))
        when 3 then ColorTable.new(kind: :rgb_triples, rows: raw.bytes.each_slice(3).to_a)
        else ColorTable.new(kind: :rgb_quads, rows: raw.bytes.each_slice(4).to_a)
        end
      end

      def layout(bytes, usage)
        header = header_size(bytes, usage) or return

        width, height, planes, bits, compression, image_size, used = header_fields(bytes, header)
        return unless valid_shape?(width, height, planes, bits) && valid_compression?(compression, bits, height)

        masks = mask_bytes(compression, header)
        colors = color_count(bits, used, usage)
        size = pixel_size(compression, width, bits, height, image_size)
        return unless masks && colors && size

        build_layout(bytes, header, masks, colors, usage, size)
      end

      def header_size(bytes, usage)
        return unless bytes.bytesize >= 4 && usage.between?(0, 2)

        size = bytes.unpack1("V")
        size unless (size != 12 && size < 40) || size > bytes.bytesize
      end

      def build_layout(bytes, header, masks, colors, usage, size)
        entry_size = color_entry_size(header, usage)
        start = header + masks + (colors * entry_size)
        return unless start + size <= bytes.bytesize && valid_profile?(bytes, header, start + size)

        Layout.new(header: header, masks: masks, color_count: colors, entry_size: entry_size, pixel_start: start, pixel_size: size)
      end

      def color_entry_size(header, usage)
        return 2 if usage == 1

        header == 12 ? 3 : 4
      end

      def header_fields(bytes, header)
        return bytes.unpack("@4v4") + [0, 0, 0] if header == 12

        width, height, planes, bits, compression, image_size = bytes.unpack("@4l<2v2V2")
        [width, height, planes, bits, compression, image_size, bytes.unpack1("@32V")]
      end

      def valid_shape?(width, height, planes, bits)
        width.positive? && !height.zero? && planes == 1 && BIT_COUNTS.include?(bits)
      end

      def valid_compression?(compression, bits, height)
        return false unless COMPRESSIONS.include?(compression)
        return false if height.negative? && ![0, 3].include?(compression)
        return false if bits.zero? && ![4, 5].include?(compression)

        RLE_BITS.fetch(compression, bits) == bits && (compression != 3 || [16, 32].include?(bits))
      end

      # Embedded masks occupy the extension in V4/V5 and later headers.
      def mask_bytes(compression, header)
        return 0 unless compression == 3
        return 12 if header == 40

        0 if header >= 52
      end

      def color_count(bits, used, usage)
        max_colors = bits.between?(1, 8) ? 1 << bits : 0
        return 0 if usage == 2
        return max_colors if used.zero?
        return if max_colors.positive? && used > max_colors

        used
      end

      def pixel_size(compression, width, bits, height, image_size)
        return (((width * bits) + 31) / 32 * 4) * height.abs if [0, 3, 11].include?(compression)

        image_size unless image_size.zero?
      end

      # A packed V5 profile may follow pixels, but may not overlap header/table/pixels.
      def valid_profile?(bytes, header, pixel_end)
        return true unless header >= 124 && PROFILE_SIGNATURES.include?(bytes.unpack1("@56V"))

        profile, profile_size = bytes.unpack("@112V2")
        profile_size.zero? || (profile >= pixel_end && profile + profile_size <= bytes.bytesize)
      end
    end

    module Bitmap16
      Image = Struct.new(:bitmap_type, :width, :height, :width_bytes, :planes, :bits_pixel, :pixels, :trailing,
                         keyword_init: true)

      module_function

      # The extent derives from Width and BitsPixel, independent of WidthBytes, which is
      # preserved verbatim even when inconsistent with that stride.
      def parse(bytes)
        bytes = bytes.b
        return unless bytes.bytesize >= 10

        type, width, height, width_bytes, planes, bits = bytes.unpack("s<4C2")
        return unless width.positive? && height.positive? && planes == 1 && bits.positive?

        size = ((((width * bits) + 15) / 16) * 2) * height
        return unless 10 + size <= bytes.bytesize

        Image.new(bitmap_type: type, width: width, height: height, width_bytes: width_bytes, planes: planes,
                  bits_pixel: bits, pixels: bytes.byteslice(10, size), trailing: bytes.byteslice((10 + size)..))
      end
    end

    # Typed interior of a bitmap transfer record: a Bitmap16::Image, a Dib::Image,
    # ABSENT for an optional source that is not present, or nil when malformed.
    module BitmapImage
      Absent = Class.new { def inspect = "#<Emf::Wmf::BitmapImage::ABSENT>" }
      ABSENT = Absent.new.freeze

      module_function

      def of(record)
        bitmap = record.bitmap
        return ABSENT if bitmap.nil?

        case record
        when Model::Wmf::Records::BitBlt, Model::Wmf::Records::StretchBlt then Bitmap16.parse(bitmap)
        when Model::Wmf::Records::DibBitBlt, Model::Wmf::Records::DibStretchBlt then Dib.parse(bitmap, 0)
        else Dib.parse(bitmap, record.color_usage)
        end
      end
    end
  end
end
