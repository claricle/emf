# frozen_string_literal: true

require "pathname"

module Emf
  module Conformance
    # Parses the input through the normal entry point and applies every rule
    # that matches the metafile's format.
    class Runner
      def initialize(profile, registry)
        @profile = profile
        @registry = registry
      end

      def call(input, now:)
        filename, bytes, metafile = load(input)
        context = build_context(metafile, bytes)
        Report.new(filename: filename, profile: @profile.name, timestamp: now, diagnostics: diagnostics(context))
      end

      private

      def load(input)
        case input
        when Model::Metafile then [nil, nil, input]
        when Pathname then [input.to_s, File.binread(input), nil]
        else
          path?(input) ? [input, File.binread(input), nil] : [nil, input.b, nil]
        end
      end

      def path?(input)
        input.is_a?(String) && !input.include?("\0") && input.bytesize < 4096 && File.file?(input)
      end

      def build_context(metafile, bytes)
        return Context.new(metafile: metafile, bytes: bytes) if metafile

        Context.new(metafile: Emf.parse(bytes), bytes: bytes)
      rescue Emf::Native::Unavailable
        raise
      rescue Emf::Error => e
        Context.new(bytes: bytes, parse_failure: e)
      end

      def diagnostics(context)
        found = @registry.rules_for(context.format).flat_map do |rule|
          rule.findings(context).map { |finding| diagnostic(rule, finding) }
        end
        found.each_with_index.sort_by { |d, index| [d.offset || -1, d.requirement_id, index] }.map(&:first)
      end

      def diagnostic(rule, finding)
        Diagnostic.new(requirement_id: rule.id, spec_citation: rule.citation, severity: @profile.severity_for(rule),
                       kind: rule.kind, format: rule.formats.first, offset: finding[:offset], record_index: finding[:record_index],
                       record_type: finding[:record_type], message: finding.fetch(:message),
                       waiver: @profile.waiver_for(rule))
      end
    end
  end
end
