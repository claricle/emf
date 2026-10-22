# frozen_string_literal: true

module Emf
  module Conformance
    # A named check. `check` is called with a Context and returns an Array of
    # findings (Hash with :message and optional :offset, :record_index, :record_type).
    Rule = Struct.new(:id, :formats, :citation, :kind, :severity, :tolerant_reason, :check, keyword_init: true) do
      def applies_to?(format) = formats.include?(format)

      def findings(context)
        found = check.call(context)
        found.is_a?(Hash) ? [found] : Array(found)
      end
    end
  end
end
