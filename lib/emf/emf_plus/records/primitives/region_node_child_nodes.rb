# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRegionNodeChildNodes (2.2.2.41): the two subtrees of a
        # combining node. RegionNode builds it, since the subtrees are nodes.
        class RegionNodeChildNodes
          attr_reader :left, :right

          def initialize(left, right)
            @left = left
            @right = right
          end

          def to_binary_s = left.to_binary_s + right.to_binary_s
        end
      end
    end
  end
end
