# frozen_string_literal: true

require "monitor"

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

      DEFAULT_LOCK = Monitor.new

      def initialize
        @rules = {}
        @loaded_files = []
      end

      def register(id:, formats:, citation:, kind:, severity: :error, tolerant_reason: nil, &check)
        raise ArgumentError, "rule #{id} needs a check block" unless check
        return @rules[id] if @rules.key?(id) && replay?(check)
        raise ArgumentError, "rule #{id} already registered" if @rules.key?(id)

        @rules[id] = Rule.new(id: id, formats: Array(formats), citation: citation, kind: kind,
                              severity: severity, tolerant_reason: tolerant_reason, check: check)
      end

      def each(&) = @rules.each_value(&)

      def loaded(file) = @loaded_files << File.expand_path(file)

      def [](id) = @rules[id]

      def rules_for(format) = select { |rule| rule.applies_to?(format) }

      # The rule's `formats.first` names its family in diagnostics (:emf, :emf_plus, :wmf).
      # Process-wide registry. Loading it requires every rules/*.rb file, so a
      # new family file is picked up without editing any list.
      def self.default = @default || DEFAULT_LOCK.synchronize { @default ||= load_from(RULES_DIR) }

      # A new registry holding every rule file found directly in `directory`.
      def self.load_from(directory)
        new.tap do |registry|
          Thread.current[:emf_conformance_registry] = registry
          Dir[File.join(directory, "*.rb")].each do |file|
            load file
            registry.loaded(file)
            # Mark it loaded, so a later `require` of the same file does not run it a second time.
            $LOADED_FEATURES << File.expand_path(file) if directory == RULES_DIR
          end
        ensure
          Thread.current[:emf_conformance_registry] = nil
        end
      end

      # The registry rule files register into while they load.
      def self.loading = Thread.current[:emf_conformance_registry] || default

      private

      # A file this registry already loaded, running again after loading finished (a later `require` of it):
      # its rules are already here. Any duplicate while loading, even from one line in a loop, still raises.
      def replay?(check)
        Thread.current[:emf_conformance_registry].nil? && @loaded_files.include?(File.expand_path(check.source_location.first))
      end
    end
  end
end
