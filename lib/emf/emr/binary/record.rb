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

        # An assignment into the bytes a shell is still made from is taken
        # before the field is made; anything else is the generic assignment.
        module PackedAssignment
          private

          def assign_field_at(index, val)
            return val if @field_objs[index].nil? && packed_assign(index, val)

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

        # A record `FastFill#call` returns is a shell: its fields are copied
        # from the filler's template, with the unpacked value assigned, the
        # first time anything asks for them (every BinData path to a field
        # goes through instantiate_obj_at). Nothing read straight from
        # @field_objs may see an unmade field as a default, so clear and
        # clear? settle the shell first.
        def initialize_instance
          @lazy_filler = @lazy_data = @lazy_base = @lazy_built = @lazy_patched = nil
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
          packed = built_binary_s unless block
          return packed if packed

          packed = FastFill.for_class(self.class)&.pack(self) unless block
          packed || super
        end

        # [data, offset, untouched] of the bytes a shell is filled from, nil
        # for any other record. `untouched` is true while no field has been
        # made: a field not made is still its bytes, a field made may have
        # been edited and is read from the wire.
        def lazy_source
          [@lazy_data, @lazy_base, !@lazy_patched && @field_objs.all?(&:nil?)] if @lazy_filler
        end

        # Makes a fresh shell (no field made) the one `FastFill#build_packed`
        # builds: its data is the whole record, packed from the attributes.
        def packed_from(data, filler)
          @lazy_data = data
          @lazy_base = 0
          @lazy_filler = filler
          @lazy_built = true
          self
        end

        # The size of a built shell no field of which, bar n_size, has been made
        # (fixed layouts never change size, a point array's size is its bytes').
        def num_bytes
          return @lazy_data.bytesize if built_clean?

          super
        end

        # The record's bytes while a built shell still is them (n_size patched
        # in), else nil.
        def built_binary_s
          return unless built_clean?

          bytes = @lazy_data.dup
          size = patched_size
          bytes.bytesplice(4, 4, [size].pack("V")) if size
          bytes
        end

        # Appends `built_binary_s` to `out` and answers true, without the copy
        # when n_size needs no patch; false (nothing appended) for any other
        # record.
        def append_built_to?(out)
          return false unless built_clean?

          out << (patched_size ? built_binary_s : @lazy_data)
          true
        end

        # Appends the record's bytes to `out`: the built fast path, else
        # `to_binary_s`.
        def append_to(out)
          return out if append_built_to?(out)

          out << to_binary_s
        end

        private

        # `n_size=` on a built shell whose n_size is not made: the new value
        # goes into the shell's own bytes (only n_size is there) and the
        # field is made, from them, if it is asked for. A value the bytes
        # already hold writes nothing: a write would copy the buffer a
        # `to_binary_s` dup still shares. Anything that is not
        # a uint32 Integer is BinData's to assign (or to refuse); nil then,
        # the assigned value otherwise.
        def packed_assign(index, value)
          return unless index == N_SIZE_INDEX && @lazy_built && @lazy_filler &&
                        value.instance_of?(Integer) && value >= 0 && value <= 0xFFFF_FFFF

          @lazy_patched = true
          data = @lazy_data
          low = value & 0xFFFF
          high = value >> 16
          return value if data.getbyte(4) | (data.getbyte(5) << 8) == low &&
                          data.getbyte(6) | (data.getbyte(7) << 8) == high

          data.setbyte(4, low & 0xFF)
          data.setbyte(5, low >> 8)
          data.setbyte(6, high & 0xFF)
          data.setbyte(7, high >> 8)
          value
        end

        N_SIZE_INDEX = 1
        private_constant :N_SIZE_INDEX

        # The n_size to patch into a built shell's bytes, nil when the bytes
        # already hold it.
        def patched_size
          size = @field_objs[N_SIZE_INDEX]&.value
          size if size && size != @lazy_data.unpack1("V", offset: 4)
        end

        # A built shell whose bytes are still the record: only n_size, which
        # is patched into them, may have been made.
        def built_clean?
          return false unless @lazy_built && @lazy_filler

          made = @field_objs.size - @field_objs.count(nil)
          return true if made.zero?

          # A value that is not an Integer is BinData's to write (or refuse).
          made == 1 && @field_objs[N_SIZE_INDEX]&.value.instance_of?(Integer)
        end

        def instantiate_obj_at(index)
          return super unless @lazy_filler
          return unless @field_objs[index].nil?

          @field_objs[index] = @lazy_filler.lazy_field(index, self, @lazy_data, @lazy_base)
        end
      end
    end
  end
end
