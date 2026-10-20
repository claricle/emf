# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetAntiAliasMode (2.3.6.1): no body. Flags bit A turns
      # anti-aliasing on; the next seven bits are the SmoothingMode value.
      class SetAntiAliasMode < Base
        TYPE = 0x401E
        ANTI_ALIAS_FLAG = 0x0001
        SMOOTHING_MODE_MASK = 0x00FE

        class SetAntiAliasModeBody < Body
          endian :little
        end
        BODY = SetAntiAliasModeBody

        def flag_fields = { anti_alias: ANTI_ALIAS_FLAG, smoothing_mode: SMOOTHING_MODE_MASK }

        def anti_alias? = flags.anybits?(ANTI_ALIAS_FLAG)
        def smoothing_mode = (flags & SMOOTHING_MODE_MASK) >> 1
      end
    end
  end
end
