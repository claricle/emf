# frozen_string_literal: true

module Emf
  module Wmf
    module Serializer
      module_function

      def call(_metafile)
        raise SerializeError, "WMF serializer not yet implemented — see TODO.impl/07-wmf-wire-domain-parser.md"
      end
    end
  end
end
