# frozen_string_literal: true

module Emf
  module Conformance
    # Ordered rule set. Rule files under conformance/rules/*.rb register
    # themselves on load:
    #
    #   Emf::Conformance::Registry.loading.register(
    #     id: "wmf.header.size", formats: [:wmf], citation: "MS-WMF 2.3.2.2",
    #     kind: :header_size, severity: :error, tolerant_reason: nil
    #   ) { |context| [{ message: "...", offset: 0 }] }
    class Registry
      RULES_DIR = File.join(__dir__, "rules")

      include Enumerable

      def initialize
        @rules = {}
      end

      def register(id:, formats:, citation:, kind:, severity: :error, tolerant_reason: nil, &check)
        raise ArgumentError, "rule #{id} already registered" if @rules.key?(id)
        raise ArgumentError, "rule #{id} needs a check block" unless check

        @rules[id] = Rule.new(id: id, formats: Array(formats), citation: citation, kind: kind,
                              severity: severity, tolerant_reason: tolerant_reason, check: check)
      end

      def each(&) = @rules.each_value(&)

      def [](id) = @rules[id]

      def rules_for(format) = select { |rule| rule.applies_to?(format) }

      # The rule's `formats.first` names its family in diagnostics (:emf, :emf_plus, :wmf).
      # Process-wide registry. Loading it requires every rules/*.rb file, so a
      # new family file is picked up without editing any list.
      def self.default = @default ||= load_from(RULES_DIR)

      # A new registry holding every rule file found directly in `directory`.
      def self.load_from(directory)
        new.tap do |registry|
          Thread.current[:emf_conformance_registry] = registry
          Dir[File.join(directory, "*.rb")].each { |file| load file }
        ensure
          Thread.current[:emf_conformance_registry] = nil
        end
      end

      # The registry rule files register into while they load.
      def self.loading = Thread.current[:emf_conformance_registry] || default
    end
  end
end
