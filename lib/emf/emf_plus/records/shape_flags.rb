# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # Record Flags bits shared by the drawing and fill records (2.3.4). The
      # low byte is an object-table index whose meaning is per record.
      module ShapeFlags
        COMPRESSED_FLAG = 0x4000
        RELATIVE_FLAG = 0x0800
        OBJECT_ID_MASK = 0x00FF

        def flag_fields
          super.merge(compressed: COMPRESSED_FLAG, relative: RELATIVE_FLAG, emf_object_id: OBJECT_ID_MASK)
        end

        def compressed? = flags.anybits?(COMPRESSED_FLAG)
        def relative? = flags.anybits?(RELATIVE_FLAG)
        def emf_object_id = flags & OBJECT_ID_MASK
      end
    end
  end
end
