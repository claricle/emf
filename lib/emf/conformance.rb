# frozen_string_literal: true

module Emf
  # Conformance lens: checks a parsed metafile against the Microsoft specs and
  # reports structured diagnostics in svg_conform's report shape.
  #
  #   Emf::Conformance.check("file.emf", profile: :tolerant).to_h
  #
  # Rules read only the public model API (records, wire fields, Metafile#errors,
  # Metafile#emf_plus_stream); they never touch a backend-specific class.
  module Conformance
    autoload :Diagnostic, "emf/conformance/diagnostic"
    autoload :Report, "emf/conformance/report"
    autoload :Profile, "emf/conformance/profile"
    autoload :Rule, "emf/conformance/rule"
    autoload :Registry, "emf/conformance/registry"
    autoload :Context, "emf/conformance/context"
    autoload :Runner, "emf/conformance/runner"
    autoload :RecordTypes, "emf/conformance/record_types"
    autoload :Manifest, "emf/conformance/manifest"
    autoload :TernaryRasterOperations, "emf/conformance/ternary_raster_operations"

    # @param input [String, Pathname, Emf::Model::Metafile] a file path, raw bytes or a parsed metafile
    # @param profile [Symbol] :strict (spec-conformant only) or :tolerant (accepts the real-world corpus)
    # @param registry [Registry] rule set; defaults to every rule file under conformance/rules
    # @return [Report]
    def self.check(input, profile: :strict, registry: Registry.default, now: Time.now)
      Runner.new(Profile.fetch(profile), registry).call(input, now: now)
    end
  end
end
