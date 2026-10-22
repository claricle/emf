# frozen_string_literal: true

module Emf
  module Model
    module Emr
      module Records
        # Adapter that wraps a bindata wire record so the Metafile container
        # can hold domain-shape objects even for record types whose dedicated
        # domain class hasn't been written yet (TODO 10). When a real domain
        # class exists, the parser uses it instead.
        #
        # `wire` is the parsed Emf::Emr::Binary::Records::* instance.
        # `offset` is the byte offset within the source stream (for diagnostics).
        class WireAdapter < Emf::Model::Record
          Emf::Model::Visitor.register_visit(:visit_emr_wire_record, self)

          # Internal native construction path; the source owns copied Ruby data only.
          # One per parsed record, so it skips keyword construction; the suffix
          # is the source's once the wire is made.
          def self.lazy(source:, offset: nil)
            allocate.__send__(:init_lazy, source, offset)
          end

          # Opt-in construction of a wire record from keyword attributes, with
          # n_size set to the record's size, as `klass.new(**attrs)` followed by
          # `n_size = num_bytes`. For a class with a PackPlan and attributes it
          # accepts (values BinData stores unchanged), the adapter holds only the
          # finished bytes; `to_binary_s` serves them until `#wire` is called,
          # after which the adapter serializes that wire like any other. Any
          # other class or attribute shape, or an error while packing, takes the
          # BinData path unchanged, so the result and the errors are those of
          # `klass.new`.
          def self.build(klass, **attrs)
            filler = Emf::Emr::Binary::FastFill.for_class(klass)
            bytes = filler && packed_bytes(filler, attrs)
            return allocate.__send__(:init_lazy, BuiltBytes.new(klass, filler, bytes), nil) if bytes

            wire = klass.new(**attrs)
            wire.n_size = wire.num_bytes
            new(wire: wire)
          end

          def self.packed_bytes(filler, attrs)
            filler.pack_plan&.pack(attrs)
          rescue StandardError
            nil
          end
          private_class_method :packed_bytes

          # The lazy source of a record built by `build`: its bytes, and a
          # wire read back from them when one is asked for.
          class BuiltBytes
            def initialize(klass, filler, bytes)
              @klass = klass
              @filler = filler
              @bytes = (bytes.encoding == Encoding::BINARY ? bytes : bytes.b).freeze
            end

            def type_id
              @bytes.unpack1("V")
            end

            def to_binary_s
              @bytes.dup
            end

            def materialize
              @filler.call_at(@bytes, 0, @bytes.bytesize)&.first || @klass.read(@bytes)
            end

            def suffix(_wire)
              EMPTY_SUFFIX
            end
          end

          # Bytes of a record that follow its typed layout (declared nSize larger
          # than the layout consumes). Kept verbatim beside the wire.
          EMPTY_SUFFIX = "".b.freeze
          private_constant :EMPTY_SUFFIX

          def self.suffix_of(record_bytes, wire)
            extra = record_bytes.bytesize - wire.num_bytes
            return EMPTY_SUFFIX unless extra.positive?

            record_bytes.byteslice(-extra, extra).b.freeze
          end

          def initialize(wire:, offset: nil, suffix: "".b)
            @wire = wire
            @offset = offset
            @suffix = suffix
          end

          attr_reader :offset

          def wire
            return @wire if @wire

            @wire = @wire_source.materialize
            @suffix = @wire_source.suffix(@wire)
            @wire_source = nil
            @wire
          end

          def suffix
            wire
            @suffix
          end

          def to_binary_s
            return @wire_source.to_binary_s unless @wire

            bytes = Emf::Emr::Binary::FastFill.for_class(@wire.class)&.pack(@wire) || @wire.to_binary_s
            return bytes if @suffix.empty?

            bytes[4, 4] = [bytes.bytesize + @suffix.bytesize].pack("V")
            bytes + @suffix
          end

          def type_id
            @wire ? @wire.i_type : @wire_source.type_id
          end

          def accept(visitor)
            visitor.visit_emr_wire_record(self)
          end

          def ==(other)
            other.is_a?(self.class) && to_binary_s == other.to_binary_s
          end
          alias eql? ==

          def hash
            [self.class, to_binary_s].hash
          end

          def inspect
            "#<#{self.class.name} type_id=#{type_id} (#{(wire.class.name || '').split('::').last})>"
          end

          private

          def init_lazy(source, offset)
            @wire = nil
            @offset = offset
            @suffix = EMPTY_SUFFIX
            @wire_source = source
            self
          end
        end
      end
    end
  end
end
