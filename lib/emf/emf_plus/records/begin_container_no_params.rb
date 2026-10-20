# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusBeginContainerNoParams (2.3.7.2): opens a container identified by StackIndex.
      class BeginContainerNoParams < Base
        TYPE = 0x4028

        class BeginContainerNoParamsBody < BinData::Record
          endian :little
          uint32 :stack_index
        end
        BODY = BeginContainerNoParamsBody

        def stack_index = body.stack_index.to_i
      end
    end
  end
end
