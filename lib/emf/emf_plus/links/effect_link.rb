# frozen_string_literal: true

module Emf
  module EmfPlus
    module Links
      # An E-flag EmfPlusDrawImagePoints frame paired with the
      # EmfPlusSerializableObject frame that supplies its effect.
      EffectLink = Struct.new(:draw, :effect, keyword_init: true) do
        def initialize(**)
          super
          freeze
        end
      end
    end
  end
end
