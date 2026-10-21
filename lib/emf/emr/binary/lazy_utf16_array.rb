# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      # A fixed-length array of little-endian uint16 that keeps the bytes it read
      # and builds the per-unit BinData objects only when an element is touched.
      # A font record read and written back untouched never pays for them.
      class LazyUtf16Array < BinData::Array
        UNIT_BYTES = 2

        default_parameter type: :uint16le

        # BinData extends each instance with its initial_length plugin, which
        # shadows class methods; extending last puts these in front of it.
        def initialize_shared_instance
          super
          extend Lazy
        end

        def initialize_instance
          super
          @raw = nil
        end

        module Lazy
          def do_read(io)
            @elements = nil
            @raw = io.readbytes(eval_parameter(:initial_length) * UNIT_BYTES)
          end

          def do_write(io)
            @raw ? io.writebytes(@raw) : super
          end

          def do_num_bytes
            @raw ? @raw.bytesize : super
          end

          def clear?
            @raw ? @raw.count("\0") == @raw.bytesize : super
          end

          def length
            @raw ? @raw.bytesize / UNIT_BYTES : super
          end
          alias size length

          def assign(array)
            return if equal?(array)

            @raw = nil
            super
          end

          private

          def elements
            materialize if @raw
            super
          end

          # Build the full element list before publishing it, so a concurrent
          # reader sees either the raw bytes or complete elements, never an
          # empty array in between.
          def materialize
            raw = @raw
            list = Array.new(raw.bytesize / UNIT_BYTES) { new_element }
            io = BinData::IO::Read.new(raw)
            list.each { |element| element.do_read(io) }
            @elements = list
            @raw = nil
          end
        end
      end
    end
  end
end

BinData::RegisteredClasses.register("lazy_utf16_array", Emf::Emr::Binary::LazyUtf16Array)
