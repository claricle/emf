# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Objects
      # Building blocks for objects whose layout depends on flags: a Cursor
      # walks the data once and collects ordered parts that a Body re-encodes.
      module Parts
        class Malformed < StandardError; end

        # What a nested object needs from the logical object it is cut from.
        Slice = Struct.new(:object_type, :data, :offset)

        # A typed object embedded in another one; it keeps its own padding.
        Nested = Struct.new(:object) do
          def num_bytes = object.to_binary.bytesize
          def to_binary_s = object.to_binary
        end

        # A 4-byte length followed by that many bytes, of which `inner` reads
        # a prefix; the rest is kept so the bytes round-trip.
        Sized = Struct.new(:byte_length, :inner, :extra) do
          def num_bytes = 4 + inner.num_bytes + extra.bytesize
          def to_binary_s = [byte_length].pack("V") + inner.to_binary_s + extra
        end

        # Ordered parts; strings are raw bytes.
        class Body
          attr_reader :parts

          def initialize(parts) = @parts = parts

          def version = parts.fetch(:header).version

          def num_bytes = parts.each_value.sum { |part| part.is_a?(String) ? part.bytesize : part.num_bytes }

          def to_binary_s = parts.each_value.map { |part| part.is_a?(String) ? part : part.to_binary_s }.join.b
        end

        # Reads parts front to back. Every count and length is checked against
        # the bytes left before anything is allocated.
        class Cursor
          attr_reader :parts

          def initialize(data)
            @data = data
            @pos = 0
            @parts = {}
          end

          def take(name, klass)
            record = klass.new
            raise Malformed, "#{name} needs #{record.num_bytes} bytes, #{remaining} left" if record.num_bytes > remaining

            @parts[name] = record.read(@data.byteslice(@pos..))
            @pos += record.num_bytes
          end

          # A BinData record that starts with a 4-byte count of `item_size` elements.
          def take_counted(name, klass, item_size)
            count = peek_uint32(name, "count")
            needed = 4 + (count * item_size)
            raise Malformed, "#{name} of #{count} entries needs #{needed} bytes, #{remaining} left" if needed > remaining

            @parts[name] = klass.read(@data.byteslice(@pos..))
            @pos += @parts[name].num_bytes
          end

          # The block builds the inner part from the length-delimited bytes.
          def take_sized(name)
            length = peek_uint32(name, "length")
            raise Malformed, "#{name} length #{length} exceeds the #{remaining - 4} bytes left" if length > remaining - 4

            body = @data.byteslice(@pos + 4, length)
            inner = yield(body)
            @parts[name] = Sized.new(length, inner, body.byteslice(inner.num_bytes..))
            @pos += 4 + length
          end

          def take_rest(name)
            rest = @data.byteslice(@pos..)
            @parts[name] = rest.freeze unless rest.empty?
            @pos += rest.bytesize
          end

          def rest = @data.byteslice(@pos..)

          def remaining = @data.bytesize - @pos

          private

          def peek_uint32(name, what)
            raise Malformed, "#{name} #{what} needs 4 bytes, #{remaining} left" if remaining < 4

            @data.byteslice(@pos, 4).unpack1("V")
          end
        end
      end
    end
  end
end
