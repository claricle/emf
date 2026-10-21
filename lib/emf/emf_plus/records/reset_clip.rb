# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusResetClip (2.3.1.2): no body; Flags are reserved.
      class ResetClip < Base
        TYPE = 0x4031

        class ResetClipBody < Body
          endian :little
        end
        BODY = ResetClipBody
      end
    end
  end
end
