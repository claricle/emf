# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # RedEyeCorrectionEffect (2.2.3.9): NumberOfAreas WMF RectL objects, read with
      # the core Emf::Binary::Types::RectL (a nested RectL would replace it in
      # BinData's global registry).
      class RedEyeCorrection < Effect
        GUID = "74d29d05-69a4-4266-9549-3cc52836b632"
        RECT_SIZE = 16

        class RedEyeCorrectionBody < Records::Body
          endian :little
          int32 :number_of_areas
          array :areas, type: :rect_l, initial_length: :number_of_areas
        end
        BODY = RedEyeCorrectionBody

        def number_of_areas = body.number_of_areas
        def areas = body.areas.map { |r| [r.left, r.top, r.right, r.bottom] }

        private

        def check_bounds
          return if buffer.bytesize < 4

          count = buffer.unpack1("l<")
          fail_parse("negative NumberOfAreas #{count}") if count.negative?
          require_room(4 + (count * RECT_SIZE), "Areas of #{count} rectangles")
        end
      end
    end
  end
end
