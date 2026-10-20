# frozen_string_literal: true

require "emf/emf_plus/records/primitives/path"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusPath object (2.2.1.6); AlignmentPadding stays in `trailing`.
      class Path < Typed
        BODY = Records::Primitives::Path

        def point_count = body.point_count
        def flags = body.flags
        def relative? = body.relative?
        def compressed? = body.compressed?
        def points = body.points.points.map { |p| [p.x, p.y] }
        def point_types = body.point_types
      end
    end
  end
end
