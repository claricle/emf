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
