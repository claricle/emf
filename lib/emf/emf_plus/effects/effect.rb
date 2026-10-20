# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Effects
      # An image effect parameter block read through a BinData class (BODY in
      # the subclass). Bytes after the body stay in `trailing`, so an unedited
      # effect re-encodes to its buffer.
      class Effect
        attr_reader :body, :trailing

        def initialize(buffer, offset:, record_code:)
          @buffer = buffer
          @offset = offset
          @record_code = record_code
          check_bounds
          @body = read_body
          @trailing = buffer.byteslice(@body.num_bytes..).freeze
        end

        def to_binary = body.to_binary_s + trailing

        private

        attr_reader :buffer

        def check_bounds; end

        def read_body
          self.class::BODY.new.read(buffer)
        rescue IOError, BinData::ValidityError => e
          fail_parse(e.message)
        end

        def fail_parse(message)
          raise ParseError.new(offset: @offset, record_code: @record_code,
                               message: "malformed #{self.class.name.split('::').last} effect at offset #{@offset}: #{message}")
        end

        def require_room(needed, what)
          return if needed <= buffer.bytesize

          fail_parse("#{what} needs #{needed} bytes, buffer holds #{buffer.bytesize}")
        end
      end
    end
  end
end
