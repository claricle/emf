# frozen_string_literal: true

require "time"
require "yaml"

module Emf
  module Conformance
    # svg_conform's ConformanceReport shape (filename, profile, tool, version,
    # timestamp, valid, errors, warnings). Issue keys follow svg_conform's with
    # `offset` (byte offset in the file) in place of line/column/xpath, which
    # have no meaning in a binary format.
    #
    # Issue keys: `kind` is the diagnostic kind and `spec_citation` the cited section (issue #37 AC2).
    # `category` (same value as `kind`) and `context.spec_citation` (same value as `spec_citation`) are
    # kept for svg_conform shape compatibility and for reports already consumed.
    #
    # Contract (pinned by spec/emf/conformance/report_spec.rb):
    # - `issues` keep the diagnostics' order (file offset ascending, offset-less
    #   findings first, then requirement id); `by_requirement` is ordered by id.
    # - Every value in `to_h` is a String, Integer, true/false or nil; keys are Strings.
    # - The only time-dependent key is "timestamp", from the `now:` given to
    #   Emf::Conformance.check. To compare two runs (for example forced backends),
    #   pass the same `now:` to both, or compare `to_h(timestamp: false)`.
    class Report
      TOOL = "emf"

      attr_reader :filename, :profile, :timestamp, :diagnostics

      def initialize(filename:, profile:, timestamp:, diagnostics:)
        @filename = filename
        @profile = profile
        @timestamp = timestamp
        @diagnostics = diagnostics.dup.freeze
      end

      def errors = diagnostics.select(&:error?)

      def warnings = diagnostics.select(&:warning?)

      def valid? = errors.empty?

      # @param timestamp [Boolean] false drops the "timestamp" key, giving a report
      #   that depends only on the input and profile
      def to_h(timestamp: true)
        head = { "filename" => filename, "profile" => profile.to_s, "tool" => TOOL, "version" => Emf::VERSION }
        head["timestamp"] = self.timestamp.utc.iso8601 if timestamp
        head.merge("valid" => valid?, "errors" => summary(errors, "error"), "warnings" => summary(warnings, "warning"))
      end

      def to_yaml(*options, timestamp: true) = to_h(timestamp: timestamp).to_yaml(*options)

      private

      def summary(list, type)
        { "total_count" => list.size,
          "by_requirement" => list.map(&:requirement_id).tally.sort.to_h,
          "issues" => list.map { |diagnostic| issue(diagnostic, type) } }
      end

      def issue(diagnostic, type)
        { "type" => type, "requirement_id" => diagnostic.requirement_id, "message" => diagnostic.message,
          "element" => element(diagnostic), "attribute" => nil, "value" => nil, "offset" => diagnostic.offset,
          "severity" => type, "kind" => diagnostic.kind.to_s, "category" => diagnostic.kind.to_s,
          "spec_citation" => diagnostic.spec_citation, "remediation_available" => false,
          "context" => context(diagnostic) }
      end

      def element(diagnostic)
        diagnostic.record_type && "#{diagnostic.format}:#{record_name(diagnostic)}"
      end

      def record_name(diagnostic)
        diagnostic.format == :emf ? RecordTypes.name(diagnostic.record_type) : format("0x%04X", diagnostic.record_type)
      end

      def context(diagnostic)
        { "spec_citation" => diagnostic.spec_citation, "format" => diagnostic.format.to_s,
          "record_index" => diagnostic.record_index, "record_type" => diagnostic.record_type,
          "waiver" => diagnostic.waiver }.compact
      end
    end
  end
end
