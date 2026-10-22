# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Reads the offset/size-addressed variable parts of a record straight from
      # its bytes, so they are visible even when a wire `body` or `trailing`
      # field absorbed them. Offsets are from record start. A part that is
      # absent, empty, starts inside the fixed layout or leaves the record is
      # nil, never an error; nothing is computed at parse time.
      #
      #   fixed_layout 100                     # bytes of the fixed layout
      #   variable_buffer :bmi_bytes, offset: :off_bmi_src, length: :cb_bmi_src
      #
      # offset, length and the fixed size are an Integer, a Symbol naming a
      # reader on the record, or a lambda run on the record.
      module VariableBuffers
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class macros.
        module ClassMethods
          attr_reader :fixed_layout_size

          def fixed_layout(size)
            @fixed_layout_size = size
          end

          def buffer_specs
            @buffer_specs ||= {}
          end

          # Declare a part and, unless reader is false, a reader named for it.
          def variable_buffer(name, offset:, length:, reader: true)
            buffer_specs[name] = [offset, length]
            define_method(name) { buffer_range(name)&.then { |range| record_bytes.byteslice(range) } } if reader
          end
        end

        # The bytes inside nSize after the fixed layout and after every declared
        # part that lies inside the record, or "" when there are none. nil when
        # nSize is smaller than the fixed layout or larger than the record.
        def layout_surplus_bytes
          bytes = record_bytes
          size = n_size
          fixed = resolve(self.class.fixed_layout_size)
          return unless fixed && size >= fixed && size <= bytes.bytesize

          finish = self.class.buffer_specs.each_key.filter_map { |name| buffer_range(name)&.end }.max
          start = [fixed, finish.to_i].max
          start >= size ? "".b : bytes.byteslice(start, size - start)
        end

        private

        def record_bytes
          to_binary_s
        end

        def buffer_range(name)
          offset, length = self.class.buffer_specs.fetch(name).map { |part| resolve(part) }
          return unless offset && length&.positive?
          return if offset < resolve(self.class.fixed_layout_size)

          finish = offset + length
          (offset...finish) if finish <= record_bytes.bytesize
        end

        def resolve(part)
          case part
          when Integer then part
          when Symbol then public_send(part)
          else instance_exec(&part)
          end
        end

        # Unsigned 32-bit value at a record offset, 0 past the end (so a part
        # sized by it is empty).
        def u32_at(offset)
          raw = record_bytes.byteslice(offset, 4)
          raw&.bytesize == 4 ? raw.unpack1("V") : 0
        end
      end
    end
  end
end
