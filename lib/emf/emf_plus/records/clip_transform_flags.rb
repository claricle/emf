# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # Record Flags readers shared by the clipping and transform records.
      module CombineModeFlags
        COMBINE_MODE_MASK = 0x0F00
        OBJECT_ID_MASK = 0x00FF

        def flag_fields = super.merge(combine_mode: COMBINE_MODE_MASK, emf_object_id: OBJECT_ID_MASK)

        def combine_mode = (flags & COMBINE_MODE_MASK) >> 8
        def emf_object_id = flags & OBJECT_ID_MASK
      end

      module PostMultiplyFlag
        POST_MULTIPLY_FLAG = 0x2000

        def flag_fields = super.merge(post_multiply: POST_MULTIPLY_FLAG)

        def post_multiply? = flags.anybits?(POST_MULTIPLY_FLAG)
      end
    end
  end
end
