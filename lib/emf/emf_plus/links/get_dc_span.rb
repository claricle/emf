# frozen_string_literal: true

module Emf
  module EmfPlus
    module Links
      # The EMF records a single EmfPlusGetDC makes drawable. `emr_range` indexes
      # Metafile#records and is empty when another EMF+ record follows the GetDC.
      GetDcSpan = Struct.new(:comment_index, :offset, :emr_range, keyword_init: true) do
        def initialize(**)
          super
          freeze
        end

        def empty? = emr_range.none?
      end
    end
  end
end
