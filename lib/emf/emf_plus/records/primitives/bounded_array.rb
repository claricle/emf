# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # A BinData array whose untrusted `initial_length` is checked against
        # the bytes left in the stream before any element is built. Each
        # element takes at least `element_size` bytes, so a count that cannot
        # fit raises EOFError (an IOError, the signal a short read already
        # gives) instead of allocating count elements.
        class BoundedArray < BinData::Array
          # Extended onto each instance after the initial-length plugin, so
          # its do_read runs first.
          module Guard
            def do_read(io)
              count = eval_parameter(:initial_length)
              needed = count * eval_parameter(:element_size)
              left = io.num_bytes_remaining
              raise EOFError, "#{count} elements need at least #{needed} bytes, #{left} left" if needed > left

              super
            end
          end

          mandatory_parameter :element_size

          def initialize_shared_instance
            super
            extend Guard
          end
        end
      end
    end
  end
end
