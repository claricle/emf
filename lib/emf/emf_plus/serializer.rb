# frozen_string_literal: true

module Emf
  module EmfPlus
    module Serializer
      module_function

      def call(_metafile)
        raise SerializeError, "EMF+ serializer not yet implemented — see TODO.impl/15-public-api.md"
      end
    end
  end
end
