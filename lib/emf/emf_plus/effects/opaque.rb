# frozen_string_literal: true

module Emf
  module EmfPlus
    module Effects
      # A parameter block of an unknown GUID, or a ColorCurve block that does
      # not fit its layout (Windows writes those corrupt, ch05 note 10).
      class Opaque
        attr_reader :buffer

        def initialize(buffer)
          @buffer = buffer
        end

        def to_binary = buffer
      end
    end
  end
end
