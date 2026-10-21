# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/point"
require "emf/emf_plus/records/primitives/point_f"
require "emf/emf_plus/records/primitives/point_r"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # `point_count` points in the form the record flags select: relative
        # (PointR) wins over compressed (Point); otherwise PointF.
        class PointArray < Body
          endian :little
          mandatory_parameter :point_count, :relative, :compressed
          array :relative_points, type: PointR, initial_length: :point_count, onlyif: -> { relative }
          array :compressed_points, type: Point, initial_length: :point_count, onlyif: -> { !relative && compressed }
          array :float_points, type: PointF, initial_length: :point_count, onlyif: -> { !relative && !compressed }

          def points
            if relative
              relative_points
            elsif compressed
              compressed_points
            else
              float_points
            end
          end

          private

          def relative = eval_parameter(:relative)
          def compressed = eval_parameter(:compressed)
        end
      end
    end
  end
end
