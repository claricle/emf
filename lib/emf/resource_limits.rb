# frozen_string_literal: true

require_relative "resource_limits/emf_records"
require_relative "resource_budget"

module Emf
  # Shared admission checks run before either parser allocates its input model.
  module ResourceLimits
    module_function

    def check!(resource, limit, actual)
      return if actual <= limit

      raise ResourceLimitError.new(resource: resource, limit: limit, actual: actual)
    end

    def preflight(bytes)
      format = Detector.call(bytes)
      limit = case format
              when :wmf_apm, :wmf_standard then Wmf::Binary::MAX_INPUT_BYTES
              when :emf then Emr::Parser::MAX_INPUT_BYTES
              end
      check!(:input_bytes, limit, bytes.bytesize)
      return unless format == :emf

      ResourceBudget.check!(bytes, limits: { input_bytes: limit,
                                             record_bytes: EmfRecords::MAX_RECORD_BYTES,
                                             record_count: EmfRecords::MAX_RECORDS }) do |type, size, base|
        EmfRecords.check_arrays(bytes, type, size, base)
      end
    end
  end
end
