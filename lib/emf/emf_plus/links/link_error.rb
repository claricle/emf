# frozen_string_literal: true

module Emf
  module EmfPlus
    module Links
      # A linking diagnostic. `reason` is :missing_effect or :non_adjacent_effect.
      LinkError = Struct.new(:reason, :comment_index, :offset, :message, keyword_init: true) do
        def initialize(**)
          super
          freeze
        end
      end
    end
  end
end
