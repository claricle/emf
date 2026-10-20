# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSave (2.3.7.5): saves the graphics state under StackIndex.
      class Save < Base
        TYPE = 0x4025

        class SaveBody < Body
          endian :little
          uint32 :stack_index
        end
        BODY = SaveBody

        def stack_index = body.stack_index.to_i
      end
    end
  end
end
