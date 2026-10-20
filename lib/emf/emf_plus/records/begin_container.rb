# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_f"

module Emf
  module EmfPlus
    module Records
      # EmfPlusBeginContainer (2.3.7.1). Flags low byte is the PageUnit
      # (UnitType); DestRect and SrcRect define the container transform.
      class BeginContainer < Base
        TYPE = 0x4027
        PAGE_UNIT_MASK = 0x00FF

        class BeginContainerBody < BinData::Record
          endian :little
          rect_f :dest_rect
          rect_f :src_rect
          uint32 :stack_index
        end
        BODY = BeginContainerBody

        def flag_fields = { page_unit: PAGE_UNIT_MASK }

        def page_unit = flags & PAGE_UNIT_MASK
        def dest_rect = body.dest_rect
        def src_rect = body.src_rect
        def stack_index = body.stack_index.to_i
      end
    end
  end
end
