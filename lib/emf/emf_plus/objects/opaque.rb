# frozen_string_literal: true

module Emf
  module EmfPlus
    module Objects
      # ObjectData of a type that has no typed body yet.
      class Opaque
        attr_reader :object_type, :data

        def initialize(logical)
          @object_type = logical.object_type
          @data = logical.data
        end

        def to_binary = data
      end
    end
  end
end
