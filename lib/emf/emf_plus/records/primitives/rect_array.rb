# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/bounded_array"
require "emf/emf_plus/records/primitives/rect"
require "emf/emf_plus/records/primitives/rect_f"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # `rect_count` rectangles, Rect when compressed and RectF otherwise.
        class RectArray < Body
          endian :little
          mandatory_parameter :rect_count, :compressed
          bounded_array :compressed_rects, type: Rect, element_size: 8, initial_length: :rect_count, onlyif: -> { compressed }
          bounded_array :float_rects, type: RectF, element_size: 16, initial_length: :rect_count, onlyif: -> { !compressed }

          def rects = eval_parameter(:compressed) ? compressed_rects : float_rects
        end
      end
    end
  end
end
