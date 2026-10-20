# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetClipRegion (2.3.1.5): combines the clip with the EmfPlusRegion
      # object named by the ObjectID flag byte. No body.
      class SetClipRegion < Base
        include CombineModeFlags

        TYPE = 0x4034

        class SetClipRegionBody < Body
          endian :little
        end
        BODY = SetClipRegionBody
      end
    end
  end
end
