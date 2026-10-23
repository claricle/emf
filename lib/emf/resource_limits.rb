# frozen_string_literal: true

module Emf
  # Shared admission checks run before either parser allocates its input model.
  module ResourceLimits
    module_function

    def check!(resource, limit, actual)
      return if actual <= limit

      raise ResourceLimitError.new(resource: resource, limit: limit, actual: actual)
    end

    def preflight(bytes)
      limit = case Detector.call(bytes)
              when :wmf_apm, :wmf_standard then Wmf::Binary::MAX_INPUT_BYTES
              when :emf then Emr::Parser::MAX_INPUT_BYTES
              end
      check!(:input_bytes, limit, bytes.bytesize)
    end
  end
end
