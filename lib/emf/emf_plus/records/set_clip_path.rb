# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetClipPath (2.3.1.3): combines the clip with the EmfPlusPath
      # object named by the ObjectID flag byte. No body.
      class SetClipPath < Base
        include CombineModeFlags

        TYPE = 0x4033

        class SetClipPathBody < Body
          endian :little
        end
        BODY = SetClipPathBody
      end
    end
  end
end
