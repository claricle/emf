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

          def initialize(wire:, offset: nil)
            @wire = wire
            @offset = offset
          end

          attr_reader :wire, :offset

          def type_id
            @wire.i_type
          end

          def accept(visitor)
            visitor.visit_emr_wire_record(self)
          end

          def ==(other)
            other.is_a?(self.class) && wire.to_binary_s == other.wire.to_binary_s
          end
          alias eql? ==

          def hash
            [self.class, wire.to_binary_s].hash
          end

          def inspect
            "#<#{self.class.name} type_id=#{type_id} (#{(@wire.class.name || '').split('::').last})>"
          end
        end
      end
    end
  end
end
