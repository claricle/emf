# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetTSClip (2.3.8.1). Flag C selects 4-byte (compressed) or
      # 8-byte rectangles. Only the 8-byte form (four INT16: x, y, width,
      # height, the EmfPlusRect layout) is decoded into rectangles; the
      # compressed byte stream stays raw in `rect_data`: the spec's scheme is
      # 1-or-2 bytes per point, delta-coded against the previous rectangle,
      # but it does not name the four coded values, the two-byte sign rule or
      # the first rectangle's reference, and it contradicts itself by also
      # fixing 4 bytes per rectangle.
      class SetTSClip < Base
        TYPE = 0x403A
        COMPRESSED_FLAG = 0x8000
        COUNT_MASK = 0x7FFF

        class SetTSClipBody < BinData::Record
          endian :little
          mandatory_parameter :data_size
          string :rect_data, read_length: :data_size
        end
        BODY = SetTSClipBody

        def flag_fields = { compressed: COMPRESSED_FLAG, rect_count: COUNT_MASK }

        def compressed? = flags.anybits?(COMPRESSED_FLAG)
        def rect_count = flags & COUNT_MASK
        def rect_data = body.rect_data.to_s

        def rects
          return [] if compressed?

          rect_data.unpack("s<*").each_slice(4).first(rect_count)
        end
      end
    end
  end
end
