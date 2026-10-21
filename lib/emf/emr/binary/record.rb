# frozen_string_literal: true

require "bindata"
require "emf/binary/class_field_accessors"

module Emf
  module Emr
    module Binary
      # All EMR records share an 8-byte header: uint32 iType, uint32 nSize.
      # Subclasses add their own fields after this.
      class Record < BinData::Record
        prepend Emf::Binary::ClassFieldAccessors

        endian :little
        uint32 :i_type
        uint32 :n_size

        # `Klass.new(**attrs)` for a fixed-layout record builds from the
        # FastFill template; every other call shape is BinData's constructor.
        def self.new(*args, **attrs)
          if args.empty? && !attrs.empty? && (filler = FastFill.for_class(self))
            wire = filler.build(attrs)
            return wire if wire
          end
          super
        end

        # Fixed-layout records serialize with one Array#pack, as WireAdapter
        # already does; a block or a layout with floats is BinData's writer.
        def to_binary_s(&block)
          packed = FastFill.for_class(self.class)&.pack(self) unless block
          packed || super
        end
      end
    end
  end
end
