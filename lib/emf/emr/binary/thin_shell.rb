# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # The lazy and thin shells of a Record (see FastFill). Included by
      # Record, so every method here is BinData's with its @field_objs
      # settled first.
      module ThinShell
        # A record `FastFill` returns is a thin shell: the record's bytes and
        # offset, no @field_objs. Its fields are copied from the filler's
        # template, with the unpacked value assigned, the first time anything
        # asks for them (every BinData path to a field goes through
        # instantiate_obj_at); that first ask also makes @field_objs, in
        # place, so the record keeps its identity and every field object
        # made afterwards is the one every later read answers. Nothing read
        # straight from @field_objs may see an unmade field as a default, so
        # clear and clear? settle the shell first.
        LAZY_IVARS = %i[@lazy_filler @lazy_data @lazy_base @lazy_built @lazy_patched].freeze

        def initialize_instance
          @lazy_filler = @lazy_data = @lazy_base = @lazy_built = @lazy_patched = nil
          super
        end

        def clear
          hydrate
          @lazy_filler = nil
          super
        end

        def clear?
          instantiate_all_objs if @lazy_filler
          super
        end

        # A frozen record cannot make @field_objs later, so it is made now;
        # its fields still fill in lazily, as a BinData record's do.
        def freeze
          hydrate if @lazy_filler
          super
        end

        # BinData's dup is shallow: a copy shares @field_objs, so a field
        # either record makes or edits is the other's too. A thin source has
        # no @field_objs yet, so it is made first and shared. The two also
        # share their bytes, so neither is untouched any more.
        def initialize_copy(source)
          super
          return unless @lazy_filler

          source.send(:hydrate)
          @field_objs = source.instance_variable_get(:@field_objs)
          @lazy_patched = true
          source.instance_variable_set(:@lazy_patched, true) unless source.frozen?
        end

        # The filler is generated code Marshal cannot dump, so a record is
        # dumped as the plain BinData record it reads as: every field made,
        # no lazy source.
        def marshal_dump
          instantiate_all_objs if @lazy_filler
          @field_objs&.each { |field| field.settle_points if field.is_a?(FastFill::FlatPoints) }
          (instance_variables - LAZY_IVARS).to_h { |name| [name, instance_variable_get(name)] }
        end

        def marshal_load(ivars)
          ivars.each { |name, value| instance_variable_set(name, value) }
          LAZY_IVARS.each { |name| instance_variable_set(name, nil) }
        end

        # Fixed-layout records serialize with one Array#pack, as WireAdapter
        # already does; a block or a layout with floats is BinData's writer.
        def to_binary_s(&block)
          packed = built_binary_s unless block
          return packed if packed

          return thin_binary_s if !block && thin_parsed?

          packed = FastFill.for_class(self.class)&.pack(self) unless block
          packed || super
        end

        # [data, offset, untouched] of the bytes a shell is filled from, nil
        # for any other record. `untouched` is true while no field has been
        # made: a field not made is still its bytes, a field made may have
        # been edited and is read from the wire.
        def lazy_source
          return unless @lazy_filler

          [@lazy_data, @lazy_base, !@lazy_patched && (@field_objs.nil? || @field_objs.all?(&:nil?))]
        end

        # Makes a fresh record the thin shell of the record at `base` of
        # `data`: no field made and no @field_objs. `params` and `names` are
        # the template's, shared as a copy of it would share them. A built
        # shell's data is the whole record, packed from the attributes.
        def thin(data, base, filler, params, names, built)
          @params = params
          @field_names = names
          @lazy_data = data
          @lazy_base = base
          @lazy_filler = filler
          @lazy_built = built
          self
        end

        # The size of a built shell no field of which, bar n_size, has been made
        # (fixed layouts never change size, a point array's size is its bytes').
        def num_bytes
          return @lazy_data.bytesize if built_clean?
          return @lazy_filler.record_size(@lazy_data, @lazy_base) if thin_parsed?

          super
        end

        # The record's bytes while a built shell still is them (n_size patched
        # in), else nil.
        def built_binary_s
          return unless built_clean?

          bytes = @lazy_data.dup
          size = patched_size
          bytes[4, 4] = [size].pack("V") if size
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
          size = @field_objs&.[](N_SIZE_INDEX)&.value
          size if size && size != @lazy_data.unpack1("V", offset: 4)
        end

        # A built shell whose bytes are still the record: only n_size, which
        # is patched into them, may have been made.
        def built_clean?
          return false unless @lazy_built && @lazy_filler
          return true if @field_objs.nil?

          made = @field_objs.size - @field_objs.count(nil)
          return true if made.zero?

          # A value that is not an Integer is BinData's to write (or refuse).
          made == 1 && @field_objs[N_SIZE_INDEX]&.value.instance_of?(Integer)
        end

        # A thin shell of a parsed record: its bytes are in the input.
        def thin_parsed?
          @field_objs.nil? && @lazy_filler && !@lazy_built
        end

        def thin_binary_s
          @lazy_data.byteslice(@lazy_base, @lazy_filler.record_size(@lazy_data, @lazy_base))
        end

        # Makes @field_objs of a thin shell: every slot unmade.
        def hydrate
          @field_objs = Array.new(@lazy_filler.field_count) if @field_objs.nil?
        end

        def find_index_of(obj)
          hydrate
          super
        end

        def instantiate_obj_at(index)
          return super unless @lazy_filler

          hydrate
          return unless @field_objs[index].nil?

          @field_objs[index] = @lazy_filler.lazy_field(index, self, @lazy_data, @lazy_base)
        end
      end
    end
  end
end
