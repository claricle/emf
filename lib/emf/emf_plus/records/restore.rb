# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusRestore (2.3.7.4): restores the graphics state saved under StackIndex.
      class Restore < Base
        TYPE = 0x4026

        class RestoreBody < BinData::Record
          endian :little
          uint32 :stack_index
        end
        BODY = RestoreBody

        def stack_index = body.stack_index.to_i
      end
    end
  end
end
