# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusEndOfFile (2.3.3.1): no body.
      class EndOfFile < Base
        TYPE = 0x4002

        class EndOfFileBody < Body
          endian :little
        end
        BODY = EndOfFileBody
      end
    end
  end
end
