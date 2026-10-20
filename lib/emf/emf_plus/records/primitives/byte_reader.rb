# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      module Primitives
        # Reads exact byte counts from a StringIO for the hand-parsed
        # structures; a short read raises EOFError (an IOError), the same
        # signal BinData gives, so callers map it to ParseError once.
        module ByteReader
          private

          def take(io, count, what)
            bytes = io.read(count)
            return bytes if bytes && bytes.bytesize == count

            raise EOFError, "#{what} needs #{count} bytes, #{io.size - io.pos} left"
          end

          def remaining(io) = io.size - io.pos
        end
      end
    end
  end
end
