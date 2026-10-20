# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawPath (2.3.4.11). ObjectID is the path; the pen is the body's PenId.
      class DrawPath < Base
        include ShapeFlags

        TYPE = 0x4015

        class DrawPathBody < Body
          endian :little
          uint32 :pen_id
        end
        BODY = DrawPathBody

        def path_id = emf_object_id
        def pen_id = body.pen_id
      end
    end
  end
end
