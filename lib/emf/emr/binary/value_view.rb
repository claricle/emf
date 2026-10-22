# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Field values of a fixed-layout or point-array wire record as plain,
      # frozen Ruby objects, with no BinData field object made.
      #
      # A view is built once per wire class from the class's own field list
      # and proved against BinData on a record with a distinct value in every
      # leaf (the bytes reader, the wire reader and BinData's own read must
      # agree, signedness and float values included). A class that cannot be
      # proved has no view: `ValueView.for_class` returns nil.
      #
      # The value object mirrors the wire: one `Data` member per field name,
      # nested structs (`rcl_bounds`, `xform`, `color`) as nested `Data`
      # objects with the wire's member names, and a counted point array as a
      # frozen Array of `Data` points (`x`, `y`). Integers are Integers
      # (signed or unsigned as the wire declares); float32 leaves are Floats,
      # NaN payloads included (the same float32 widening BinData applies).
      #
      # Three readers produce equal objects: `from_bytes` unpacks a record's
      # bytes with one String#unpack, `from_wire` reads the wire's values, and
      # `from_mixed` reads a lazy shell, taking each field the shell has made
      # from the wire and the others from the bytes.
      class ValueView
        # Namespace of the generated value classes.
        module Values; end

        # A layout the view does not support.
        class Unsupported < StandardError; end

        autoload :Layout, "emf/emr/binary/value_view/layout"
        autoload :ReaderSource, "emf/emr/binary/value_view/reader_source"

        BINDATA_WRITER = BinData::Base.instance_method(:to_binary_s)
        private_constant :BINDATA_WRITER

        @views = {}.compare_by_identity
        # Marks every value class, whichever base class it is built on.
        module Value; end

        @value_classes = {}.compare_by_identity
        @lock = Mutex.new

        class << self
          # The view of a wire class, or nil when the class has none.
          def for_class(wire_class)
            @views.fetch(wire_class) { @lock.synchronize { @views[wire_class] = build(wire_class) } }
          end

          # The shared value class of a BinData struct class with these members.
          def value_class(struct_class, members)
            @value_classes[struct_class] ||= define_value_class(members).tap do |klass|
              name = struct_class.name&.split("::")&.last
              Values.const_set(name, klass) if name&.match?(/\A[A-Z]\w*\z/) && !Values.const_defined?(name, false)
            end
          end

          private

          # Data (Ruby 3.2+) where it exists; on Ruby 3.1 a Struct whose
          # instances freeze themselves, so values stay frozen everywhere.
          def define_value_class(members)
            klass = defined?(::Data.define) ? ::Data.define(*members) : frozen_struct(members)
            klass.include(Value)
          end

          def frozen_struct(members)
            Struct.new(*members) do
              def initialize(*)
                super
                freeze
              end
            end
          end

          def build(wire_class)
            filler = FastFill.for_class(wire_class)
            return unless filler && !filler.is_a?(FastFill::TextFill)

            new(wire_class).tap(&:prove)
          rescue StandardError
            nil
          end
        end

        attr_reader :wire_class, :value_class

        def initialize(wire_class)
          @wire_class = wire_class
          @layout = Layout.new(wire_class)
          @value_class = @layout.tree.first
          generate
        end

        # The values of the record at `base` of the binary `data`; nil when
        # its point count overruns the record.
        def from_bytes(data, base) = read_bytes(data, base)

        # The values of a lazy shell over the record at `base` of `data`:
        # each top-level field the shell has made from the wire, the others
        # from the bytes. Nil when the point count overruns the record.
        def from_mixed(data, base, wire) = read_mixed(data, base, wire)

        # The values the wire holds now.
        def from_wire(wire) = read_wire(wire)

        # Raises unless the readers agree with BinData on a distinct-valued record.
        def prove
          sample = distinct_sample
          bytes = BINDATA_WRITER.bind_call(sample)
          values = read_bytes("\xAA\xBB".b + bytes + "\xCC".b, 2)
          reference = read_wire(@wire_class.read(bytes))
          raise Unsupported, "bytes and wire differ" unless values == read_wire(sample) && values == reference
          raise Unsupported, "a count past the record was read" unless overrun_rejected?(bytes)

          self
        end

        private

        def generate
          mod = Module.new
          mod.const_set(:CLASSES, @layout.classes.freeze)
          mod.const_set(:POINT, @layout.array[:klass]) if @layout.array
          mod.module_eval(ReaderSource.new(@layout).to_s, __FILE__, __LINE__)
          extend(mod)
        end

        # A record with a distinct value in every leaf: negative signed, high
        # unsigned, fractional floats.
        def distinct_sample
          wire = @wire_class.new
          @layout.leaf_paths.each_with_index do |path, index|
            target = path.inject(wire) { |obj, name| obj.public_send(name) }
            target.assign(distinct(@layout.leaves.fetch(index), index))
          end
          fill_array(wire)
        end

        def distinct(leaf, index)
          return index + 1.5 if leaf[:float]

          case leaf[:klass]
          when "BinData::Int32le" then -(index + 1) * 1000
          when "BinData::Uint32le" then 0xFFFF_FF00 - index
          else 0x80 + index
          end
        end

        def fill_array(wire)
          array = @layout.array
          return wire unless array

          limit = array[:bytes] == 8 ? 2**31 : 2**15
          wire.public_send(array[:count]).assign(3)
          wire.public_send(array[:name]).assign([{ x: -1, y: limit - 1 }, { x: 5, y: -limit }, { x: 0, y: 7 }])
          wire
        end

        # A count claiming more points than the record holds reads as nil.
        def overrun_rejected?(bytes)
          return true unless @layout.array

          bad = bytes.dup
          bad[@layout.leaves.fetch(@layout.count_index)[:at], 4] = [1_000_000].pack("V")
          read_bytes(bad, 0).nil?
        end
      end
    end
  end
end
