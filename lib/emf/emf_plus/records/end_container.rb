# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusEndContainer (2.3.7.3): closes the container identified by StackIndex.
      class EndContainer < Base
        TYPE = 0x4029

        class EndContainerBody < BinData::Record
          endian :little
          uint32 :stack_index
        end
        BODY = EndContainerBody

        def stack_index = body.stack_index.to_i
      end
    end
  end
end
