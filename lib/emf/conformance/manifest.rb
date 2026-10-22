# frozen_string_literal: true

require "yaml"

module Emf
  module Conformance
    # The requirement manifest: one row per rule (implemented) or per known
    # constraint the lens cannot check yet (blocked:model, not_checkable, deferred).
    # Rows live in manifest/<family>.yml, so adding a family means adding a file.
    #
    #   - id: emf.restoredc.saved_dc   # the registered rule id when implemented
    #     format: emf                  # emf | emf_plus | wmf
    #     record_types: [EMR_RESTOREDC] # [] when the rule is not tied to one record type
    #     citation: "MS-EMF 2.3.11.6"
    #     status: implemented          # implemented | blocked:model | not_checkable | deferred
    #     reason: null                 # required unless implemented
    #
    # Statuses: implemented (a registered rule), blocked:model (needs a public model
    # accessor that does not exist), not_checkable (no input can violate it, or the
    # bytes are ignored on receipt), deferred (readable from the public model today,
    # no rule written yet).
    module Manifest
      DIR = File.join(__dir__, "manifest")
      FORMATS = %w[emf emf_plus wmf].freeze
      STATUSES = %w[implemented blocked:model not_checkable deferred].freeze
      KEYS = %w[id format record_types citation status reason].freeze

      Row = Struct.new(:id, :format, :record_types, :citation, :status, :reason, :source, keyword_init: true) do
        def implemented? = status == "implemented"
      end

      module_function

      # Every row of every manifest file, in file-name then file order.
      # @param directory [String] folder of family files
      # @return [Array<Row>] frozen rows; each carries its `source` file name
      def rows(directory = DIR)
        Dir[File.join(directory, "*.yml")].flat_map { |path| load_file(path) }.freeze
      end

      # Problems that make a row unusable, as strings. Empty when well formed.
      def problems(row)
        [
          ("id must be a non-empty string" unless row.id.is_a?(String) && !row.id.empty?),
          ("format #{row.format.inspect} is not one of #{FORMATS.join(', ')}" unless FORMATS.include?(row.format)),
          ("record_types must be an Array of record names or numeric codes" unless record_types?(row.record_types)),
          ("citation must be a non-empty string" unless row.citation.is_a?(String) && !row.citation.empty?),
          ("status #{row.status.inspect} is not one of #{STATUSES.join(', ')}" unless STATUSES.include?(row.status)),
          reason_problem(row)
        ].compact
      end

      def load_file(path)
        entries = YAML.safe_load_file(path)
        raise ArgumentError, "#{path}: expected an Array of rows" unless entries.is_a?(Array)

        entries.map { |entry| row(entry, File.basename(path)) }
      end

      def row(entry, source)
        raise ArgumentError, "#{source}: row is not a mapping: #{entry.inspect}" unless entry.is_a?(Hash)

        unknown = entry.keys - KEYS
        raise ArgumentError, "#{source}: unknown keys #{unknown.inspect} in row #{entry['id'].inspect}" unless unknown.empty?

        Row.new(**entry.transform_keys(&:to_sym), source: source).freeze
      end

      # Names (EMR_RESTOREDC) or numeric record-function codes (WMF's 0x0102 as 258).
      def record_types?(value) = value.is_a?(Array) && value.all? { |type| type.is_a?(String) || type.is_a?(Integer) }

      def reason_problem(row)
        return if row.implemented? ? row.reason.nil? : row.reason.is_a?(String) && !row.reason.strip.empty?

        row.implemented? ? "an implemented row must not carry a reason" : "#{row.status} row needs a reason"
      end
    end
  end
end
