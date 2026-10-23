# frozen_string_literal: true

require "bindata"
require "emf/binary/class_field_accessors"
require "emf/emr/binary/thin_shell"

module Emf
  module Emr
    module Binary
      # All EMR records share an 8-byte header: uint32 iType, uint32 nSize.
      # Subclasses add their own fields after this.
      class Record < BinData::Record
        include ThinShell
        prepend Emf::Binary::ClassFieldAccessors

        # An assignment into the bytes a shell is still made from is taken
        # before the field is made; anything else is the generic assignment.
        module PackedAssignment
          private

          def assign_field_at(index, val)
            return val if (@field_objs.nil? || @field_objs[index].nil?) && packed_assign(index, val)

            super
          end
        end
        prepend PackedAssignment

        endian :little
        uint32 :i_type
        uint32 :n_size

        NO_ARG = Object.new.freeze
        private_constant :NO_ARG

        # `Klass.new(**attrs)` for a fixed-layout record builds from the
        # FastFill template; every other call shape is BinData's constructor.
        # BinData takes at most three positionals (value, parameters,
        # parent), named here so the hot call allocates no splat array.
        def self.new(value = NO_ARG, parameters = NO_ARG, parent = NO_ARG, **attrs)
          if NO_ARG.equal?(value) && !attrs.empty? && (filler = FastFill.for_class(self))
            wire = filler.build_packed(attrs) || filler.build(attrs)
            return wire if wire
          end
          super(*[value, parameters, parent].take_while { |arg| !NO_ARG.equal?(arg) }, **attrs)
        end
      end
    end
  end
end
