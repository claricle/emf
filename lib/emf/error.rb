# frozen_string_literal: true

module Emf
  class Error < StandardError; end

  class FormatError < Error; end

  class ParseError < Error
    attr_reader :offset, :record_code

    def initialize(offset:, record_code:, message:)
      @offset = offset
      @record_code = record_code
      super(message)
    end
  end

  class SerializeError < Error; end
end
