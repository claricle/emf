# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Objects
      # A graphics object read through a BinData class (BODY in the subclass).
      # Bytes after the body (alignment padding) stay in `trailing`, so an
      # unedited object re-encodes to its ObjectData.
      class Typed
        attr_reader :object_type, :body, :trailing

        def initialize(logical)
          @object_type = logical.object_type
          data = logical.data
          check_bounds(data, logical)
          @body = read_body(data, logical)
          @trailing = data.byteslice(@body.num_bytes..).freeze
        end

        def to_binary = body.to_binary_s + trailing

        def version = body.version.raw

        private

        def check_bounds(_data, _logical); end

        def read_body(data, logical)
          self.class::BODY.new.read(data)
        rescue IOError, BinData::ValidityError => e
          fail_parse(logical, e.message)
        end

        def fail_parse(logical, message)
          name = self.class.name.split("::").last
          raise ParseError.new(offset: logical.offset, record_code: Records::Object::TYPE,
                               message: "malformed #{name} object at offset #{logical.offset}: #{message}")
        end

        def require_room(data, logical, needed, what)
          return if needed <= data.bytesize

          fail_parse(logical, "#{what} needs #{needed} bytes, object holds #{data.bytesize}")
        end
      end
    end
  end
end
