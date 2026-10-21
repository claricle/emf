# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # The EMF records (indices into Metafile#records) lying between two
      # EMF+-bearing comments, or before the first / after the last one.
      class EmfGap
        attr_reader :range

        def initialize(range)
          @range = range
          freeze
        end

        def gap? = true
      end
    end
  end
end
