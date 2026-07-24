# frozen_string_literal: true

# Placeholder for TODO.impl/11-emf-parser.md's path-association pass.
module Emf
  module Emr
    class PathAssociation
      def initialize
        @table = {}
      end

      def lookup(render_offset)
        @table.fetch(render_offset, nil)
      end
    end
  end
end
