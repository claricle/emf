# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusImageAttributes (2.2.1.5).
      class ImageAttributes < Typed
        class ImageAttributesBody < Records::Body
          endian :little
          graphics_version :version
          uint32 :reserved1
          uint32 :wrap_mode
          argb :clamp_color
          int32 :object_clamp
          uint32 :reserved2
        end
        BODY = ImageAttributesBody

        def wrap_mode = body.wrap_mode
        def clamp_color = body.clamp_color
        def object_clamp = body.object_clamp
      end
    end
  end
end
