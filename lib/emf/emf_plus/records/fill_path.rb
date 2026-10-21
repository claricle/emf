# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillPath (2.3.4.17). S solid colour brush; ObjectID is the path.
      class FillPath < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x4014

        class FillPathBody < Body
          endian :little
          uint32 :brush_id
        end
        BODY = FillPathBody

        def path_id = emf_object_id
      end
    end
  end
end
