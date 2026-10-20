# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/rect"
require "emf/emf_plus/records/primitives/rect_f"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # `rect_count` rectangles, Rect when compressed and RectF otherwise.
        class RectArray < BinData::Record
          endian :little
          mandatory_parameter :rect_count, :compressed
          array :compressed_rects, type: Rect, initial_length: :rect_count, onlyif: -> { compressed }
          array :float_rects, type: RectF, initial_length: :rect_count, onlyif: -> { !compressed }

          def rects = eval_parameter(:compressed) ? compressed_rects : float_rects
        end
      end
    end
  end
end
