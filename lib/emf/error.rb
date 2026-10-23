# frozen_string_literal: true

module Emf
  class Error < StandardError
    # Backend-neutral ParseEvidence for a failed header or framing check, or nil when none is available.
    attr_reader :evidence

    def with_evidence(evidence)
      @evidence ||= evidence
      self
    end
  end

  class FormatError < Error; end

  class ParseError < Error
    attr_reader :offset, :record_code

    def initialize(offset:, record_code:, message:)
      @offset = offset
      @record_code = record_code
      super(message)
    end
  end

  class ResourceLimitError < Error
    attr_reader :resource, :limit, :actual

    def initialize(resource:, limit:, actual:)
      @resource = resource
      @limit = limit
      @actual = actual
      super("#{resource} limit exceeded (#{actual} > #{limit})")
    end
  end

  class SerializeError < Error; end

  module EmfPlus
    class StaleStreamError < Error; end
  end
end
