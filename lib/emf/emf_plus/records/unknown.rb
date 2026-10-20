# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # A record type without a typed class; the frame is kept as is.
      class Unknown
        attr_reader :frame

        def initialize(frame)
          @frame = frame
        end

        def type = frame.type
        def flags = frame.flags
        def to_binary = frame.to_binary
      end
    end
  end
end
