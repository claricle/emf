# frozen_string_literal: true

module Emf
  module Conformance
    # Decides severity. strict: every rule at its declared severity.
    # tolerant: a rule that carries a `tolerant_reason` is downgraded to a warning.
    class Profile
      attr_reader :name

      def initialize(name, downgrade:)
        @name = name
        @downgrade = downgrade
        freeze
      end

      def severity_for(rule)
        @downgrade && rule.tolerant_reason ? :warning : rule.severity
      end

      def waiver_for(rule)
        rule.tolerant_reason if @downgrade
      end

      STRICT = new(:strict, downgrade: false)
      TOLERANT = new(:tolerant, downgrade: true)
      ALL = { strict: STRICT, tolerant: TOLERANT }.freeze

      def self.fetch(name)
        return name if name.is_a?(Profile)

        ALL.fetch(name.to_sym) { raise ArgumentError, "unknown conformance profile: #{name.inspect} (expected strict or tolerant)" }
      end
    end
  end
end
