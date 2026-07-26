# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMRSMALLTEXTOUT (MS-EMF 2.3.5.37).
        # Layout: emr, Dest, cChars, fuOptions, iGraphicsMode, exScale (float),
        # eyScale (float), [optional RECTL], TextString (1 or 2 bytes per char).
        # The body bytes (after the fixed header) are deferred to the visitor
        # for parsing because the layout depends on fuOptions.
        class SmallTextOut < Emf::Emr::Binary::Record
          int32 :x_dest
          int32 :y_dest
          uint32 :c_chars
          uint32 :fu_options
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          rest :body
        end
      end
    end
  end
end
