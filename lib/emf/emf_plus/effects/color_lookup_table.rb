# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # ColorLookupTableEffect (2.2.3.5).
      class ColorLookupTable < Effect
        GUID = "a7ce72a9-0f7f-40d7-b3cc-d0c02d5c3212"

        class ColorLookupTableBody < Records::Body
          endian :little
          string :blue_lookup_table, length: 256
          string :green_lookup_table, length: 256
          string :red_lookup_table, length: 256
          string :alpha_lookup_table, length: 256
        end
        BODY = ColorLookupTableBody

        def blue_lookup_table = body.blue_lookup_table.to_s
        def green_lookup_table = body.green_lookup_table.to_s
        def red_lookup_table = body.red_lookup_table.to_s
        def alpha_lookup_table = body.alpha_lookup_table.to_s
      end
    end
  end
end
