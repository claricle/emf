# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # Collects record replacements for Stream#edit.
      class Editor
        attr_reader :stream

        def initialize(stream)
          @stream = stream
        end

        def replace(handle, record)
          @stream = @stream.with_record(handle, record)
          self
        end
      end
    end
  end
end
