# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/bitmap"
require "emf/emf_plus/records/primitives/metafile"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusImage (2.2.1.4). ImageDataType 1 carries an EmfPlusBitmap, 2 an
      # EmfPlusMetafile; any other value keeps its bytes in unrecognized_data.
      class Image < Typed
        BITMAP = 1
        METAFILE = 2
        TYPE_OFFSET = 4
        BITMAP_TYPE_END = 28
        PIXEL_FORMAT_OFFSET = 20
        BITMAP_TYPE_OFFSET = 24
        PALETTE_COUNT_OFFSET = 32
        PALETTE_ENTRIES_OFFSET = 36
        METAFILE_SIZE_OFFSET = 12
        METAFILE_DATA_OFFSET = 16

        class ImageBody < BinData::Record
          endian :little
          graphics_version :version
          uint32 :image_type
          bitmap :bitmap, onlyif: -> { image_type == BITMAP }
          metafile :metafile, onlyif: -> { image_type == METAFILE }
          rest :unrecognized_data, onlyif: -> { ![BITMAP, METAFILE].include?(image_type) }
        end
        BODY = ImageBody

        def image_type = body.image_type
        def bitmap = (body.bitmap if image_type == BITMAP)
        def metafile = (body.metafile if image_type == METAFILE)

        private

        def check_bounds(data, logical)
          return if data.bytesize < 8

          case data.byteslice(TYPE_OFFSET, 4).unpack1("V")
          when BITMAP then check_palette(data, logical)
          when METAFILE then check_metafile(data, logical)
          end
        end

        def check_palette(data, logical)
          return if data.bytesize < PALETTE_ENTRIES_OFFSET

          pixel_format, bitmap_type = data.byteslice(PIXEL_FORMAT_OFFSET, 8).unpack("VV")
          return unless bitmap_type.zero? && pixel_format.anybits?(Records::Primitives::Bitmap::INDEXED_FLAG)

          count = data.byteslice(PALETTE_COUNT_OFFSET, 4).unpack1("V")
          require_room(data, logical, PALETTE_ENTRIES_OFFSET + (count * 4), "Palette of #{count} entries")
        end

        def check_metafile(data, logical)
          return if data.bytesize < METAFILE_DATA_OFFSET

          size = data.byteslice(METAFILE_SIZE_OFFSET, 4).unpack1("V")
          require_room(data, logical, METAFILE_DATA_OFFSET + size, "MetafileData of #{size} bytes")
        end
      end
    end
  end
end
