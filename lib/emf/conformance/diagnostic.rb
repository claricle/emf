# frozen_string_literal: true

module Emf
  module Conformance
    # One finding. `severity` is already resolved by the profile; `waiver` holds
    # the written reason when the tolerant profile downgraded an error.
    Diagnostic = Struct.new(:requirement_id, :spec_citation, :severity, :kind, :format, :offset,
                            :record_index, :record_type, :message, :waiver, keyword_init: true) do
      def initialize(**)
        super
        freeze
      end

      def error? = severity == :error
      def warning? = severity == :warning
    end
  end
end
