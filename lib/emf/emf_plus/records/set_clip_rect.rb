# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_f"

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetClipRect (2.3.1.4): combines the clip with ClipRect.
      class SetClipRect < Base
        include CombineModeFlags

        TYPE = 0x4032

        class SetClipRectBody < BinData::Record
          endian :little
          rect_f :clip_rect
        end
        BODY = SetClipRectBody

        def clip_rect = body.clip_rect
      end
    end
  end
end
