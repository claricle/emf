# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      # A framed record whose body is read through a BinData class (BODY in the
      # subclass). Bytes after the body (padding, unknown trailing data) are
      # kept in `trailing`, so an unedited record re-encodes to its frame bytes.
      class Base
        attr_reader :type, :flags, :size, :data_size, :offset, :comment_index, :body, :trailing

        def initialize(frame)
          @type = frame.type
          @flags = frame.flags
          @size = frame.size
          @data_size = frame.data_size
          @offset = frame.offset
          @comment_index = frame.comment_index
          @body = read_body(frame)
          @trailing = frame.data.byteslice(@body.num_bytes..).freeze
        end

        def to_binary
          [type, flags, size, data_size].pack("vvVV") + body.to_binary_s + trailing
        end

        private

        def read_body(frame)
          self.class::BODY.new(data_size: data_size, flags: flags).read(frame.data.byteslice(0, data_size))
        rescue IOError, BinData::ValidityError => e
          raise ParseError.new(offset: offset, record_code: type,
                               message: "malformed #{self.class.name.split('::').last} body at offset #{offset}: #{e.message}")
        end
      end
    end
  end
end
