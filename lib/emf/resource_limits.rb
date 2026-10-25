# frozen_string_literal: true

require_relative "resource_limits/emf_records"
require_relative "resource_budget"

module Emf
  # Shared admission checks run before either parser allocates its input model.
  module ResourceLimits
    module_function

    def check!(resource, limit, actual)
      return if actual <= limit

      error = ResourceLimitError.new(resource: resource, limit: limit, actual: actual)
      error.with_evidence(yield) if block_given?
      raise error
    end

    def preflight(bytes, defer: false)
      format = Detector.call(bytes)
      limit = case format
              when :wmf_apm, :wmf_standard then Wmf::Binary::MAX_INPUT_BYTES
              when :emf then Emr::Parser::MAX_INPUT_BYTES
              end
      check!(:input_bytes, limit, bytes.bytesize) do
        check = format == :emf ? :emf_input_too_large : :input_too_large
        ParseEvidence.new(check: check, offset: 0, declared: limit, actual: bytes.bytesize)
      end
      return unless format == :emf
      return :deferred if defer && bounded_emf?(bytes)

      ResourceBudget.check!(bytes, limits: { input_bytes: limit,
                                             record_bytes: EmfRecords::MAX_RECORD_BYTES,
                                             record_count: EmfRecords::MAX_RECORDS }) do |type, size, base|
        EmfRecords.check_arrays(bytes, type, size, base)
      end
      nil
    end

    # Except for PolyText's potentially overlapping descriptors, native charges
    # are bounded by input length. Geometric record/diagnostic reservations cost
    # less than 184 bytes per input byte; input, font and payload copies fit in
    # the remaining 72. Framing and payload work fit within four units per byte.
    # The Ruby parser must request exact admission if it encounters PolyText.
    def bounded_emf?(bytes)
      size = bytes.bytesize
      header = bytes.unpack1("V", offset: 4)
      return false unless header <= size && (header == 88 || header == 100 || header >= 108)

      limits = ResourceBudget::DEFAULT_LIMITS
      size <= EmfRecords::MAX_RECORD_BYTES &&
        size / 8 <= EmfRecords::MAX_RECORDS &&
        size / 4 <= Emr::Parser::MAX_SANE_ARRAY_LENGTH &&
        size * 256 <= limits.fetch(:allocated_bytes) &&
        size * 4 <= limits.fetch(:work_units)
    end
  end
end
