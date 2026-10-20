# frozen_string_literal: true

require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      # The S flag of a fill record says whether BrushId is an ARGB colour or
      # an EmfPlusBrush index in the object table.
      module FillBrush
        SOLID_COLOR_FLAG = 0x8000

        def flag_fields = super.merge(solid_color: SOLID_COLOR_FLAG)

        def solid_color? = flags.anybits?(SOLID_COLOR_FLAG)
        def brush_id = body.brush_id
        def brush_color = Primitives::ARGB.read([brush_id].pack("V"))
      end
    end
  end
end
