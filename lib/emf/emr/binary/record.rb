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

        # A record `FastFill#call` returns is a shell: its fields are copied
        # from the filler's template, with the unpacked value assigned, the
        # first time anything asks for them (every BinData path to a field
        # goes through instantiate_obj_at). Nothing read straight from
        # @field_objs may see an unmade field as a default, so clear and
        # clear? settle the shell first.
        def initialize_instance
          @lazy_filler = @lazy_data = @lazy_base = nil
          super
        end

        def clear
          @lazy_filler = nil
          super
        end

        def clear?
          instantiate_all_objs if @lazy_filler
          super
        end

        # Fixed-layout records serialize with one Array#pack, as WireAdapter
        # already does; a block or a layout with floats is BinData's writer.
        def to_binary_s(&block)
          packed = FastFill.for_class(self.class)&.pack(self) unless block
          packed || super
        end

        # [data, offset, untouched] of the bytes a shell is filled from, nil
        # for any other record. `untouched` is true while no field has been
        # made: a field not made is still its bytes, a field made may have
        # been edited and is read from the wire.
        def lazy_source
          [@lazy_data, @lazy_base, @field_objs.all?(&:nil?)] if @lazy_filler
        end

        private

        def instantiate_obj_at(index)
          return super unless @lazy_filler
          return unless @field_objs[index].nil?

          @field_objs[index] = @lazy_filler.lazy_field(index, self, @lazy_data, @lazy_base)
        end
      end
    end
  end
end
