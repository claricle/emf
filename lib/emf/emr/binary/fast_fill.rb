# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Copy of an instantiated BinData struct tree. BinData builds each lazy
      # field by cloning a prototype, which dominates `new` plus first access
      # for a record; cloning the finished tree gives the same objects (same
      # classes, params, nil values, parent links) at a fraction of the cost.
      # Relies on BinData::Struct#@field_objs and Base#@parent, as
      # Emf::Binary::ClassFieldAccessors already does for @field_objs.
      module WireCopy
        module_function

        def call(template, parent)
          copy = template.dup
          copy.instance_variable_set(:@parent, parent)
          objs = template.instance_variable_get(:@field_objs).map do |field|
            field.respond_to?(:field_names) ? call(field, copy) : leaf(field, copy)
          end
          copy.instance_variable_set(:@field_objs, objs)
          copy
        end

        # Field name to position in @field_objs.
        def slots(sample)
          fields = sample.send(:get_parameter, :fields)
          fields.each_with_index.with_object({}) do |(field, index), slots|
            slots[field.name_as_sym] = index if field.name_as_sym
          end.freeze
        end

        # A copy of the template with each given field assigned, as BinData's
        # constructor does after instantiating the fields one by one. BinData
        # skips nil values in a constructor hash, so does this.
        def build(template, slots, attrs)
          return unless attrs.each_key.all? { |name| slots.key?(name) }

          wire = call(template, nil)
          objs = wire.instance_variable_get(:@field_objs)
          attrs.each { |name, value| objs[slots[name]].assign(value) unless value.nil? }
          wire
        end

        def leaf(leaf, parent)
          copy = leaf.dup
          copy.instance_variable_set(:@parent, parent)
          copy
        end
      end

      # Eager fill of fixed-layout records: one String#unpack for the whole
      # record, then leaf assignment into a fresh instance of the same wire
      # class. The unpack format and leaf paths are derived once per class
      # from its field list, so the result is indistinguishable from `read`.
      class FastFill
        DIRECTIVES = {
          "BinData::Uint32le" => "V",
          "BinData::Int32le" => "l<",
          "BinData::Uint8" => "C",
          "Emf::Binary::Float32Le" => "V"
        }.freeze
        FLOAT_LEAF = "Emf::Binary::Float32Le"
        EMPTY_SUFFIX = "".b.freeze
        private_constant :DIRECTIVES, :FLOAT_LEAF, :EMPTY_SUFFIX

        def self.for(type_id)
          BY_TYPE[type_id]
        end

        def self.for_class(wire_class)
          BY_CLASS[wire_class]
        end

        attr_reader :size, :wire_class

        def initialize(klass)
          @wire_class = klass
          sample = klass.new
          @size = sample.num_bytes
          leaves = leaf_paths(sample, [])
          # leaf_paths touched every field, so the sample is fully instantiated.
          @template = sample
          @format = leaves.map { |_, field| DIRECTIVES.fetch(field.name) }.join
          # Float layouts are not packed: measured on test-000, BinData writes
          # SETWORLDTRANSFORM in 15 objects against 18+ for a value pack, and
          # Float32Le must write its retained NaN bits itself.
          @pack_format = @format unless leaves.any? { |_, field| float?(field) }
          @slots = WireCopy.slots(sample)
          generate_call(leaves)
          generate_pack(leaves)
        end

        # Keyword construction, `wire_class.new(**attrs)`; nil when a key is
        # not a field, so the caller falls back to BinData.
        def build(attrs)
          WireCopy.build(@template, @slots, attrs)
        end

        private

        def float?(field)
          field.name == FLOAT_LEAF
        end

        def suffix(record_bytes)
          return EMPTY_SUFFIX if record_bytes.bytesize == @size

          record_bytes.byteslice(@size, record_bytes.bytesize - @size).b.freeze
        end

        def leaf_paths(record, prefix)
          record.field_names.flat_map do |name|
            field = record.public_send(name)
            if field.respond_to?(:field_names)
              leaf_paths(field, prefix + [name])
            else
              [[prefix + [name], field.class]]
            end
          end
        end

        # One specialized `call` per wire class: the record is unpacked into
        # locals and each leaf is assigned through the accessors BinData
        # already resolved for the class, with no per-leaf dispatch loop.
        def generate_call(leaves)
          locals = []
          lines = leaves.each_with_index.map do |(path, field), index|
            value = "v#{index}"
            locals << value
            target = accessor_chain(path)
            verb = float?(field) ? "assign_bits" : "assign"
            "#{target}.#{verb}(#{value})"
          end
          define_generated(:call, <<~RUBY)
            def call(record_bytes)
              #{locals.join(', ')} = record_bytes.unpack(@format)
              wire = WireCopy.call(@template, nil)
              #{lines.join("\n  ")}
              [wire, suffix(record_bytes)]
            end
          RUBY
        end

        def generate_pack(leaves)
          if @pack_format
            reads = leaves.map { |path, _| "#{accessor_chain(path)}.value" }
            body = "[#{reads.join(', ')}].pack(@pack_format)"
          else
            body = "nil"
          end
          define_generated(:pack, "def pack(wire)\n  #{body}\nend\n")
        end

        def accessor_chain(path)
          path.inject("wire") { |expr, name| "#{expr}.#{name}" }
        end

        def define_generated(name, source)
          singleton_class.class_eval(source, __FILE__, __LINE__)
          singleton_class.send(:public, name)
        end

        ENABLED_TYPES = [
          TypeCodes::SELECTOBJECT, TypeCodes::MOVETOEX, TypeCodes::LINETO,
          TypeCodes::DELETEOBJECT, TypeCodes::CREATEBRUSHINDIRECT,
          TypeCodes::SETBKCOLOR, TypeCodes::SETPIXELV, TypeCodes::CREATEPEN,
          TypeCodes::SETBKMODE, TypeCodes::SETTEXTCOLOR, TypeCodes::SETTEXTALIGN,
          TypeCodes::ELLIPSE, TypeCodes::SETVIEWPORTORGEX, TypeCodes::RESTOREDC,
          TypeCodes::SETWORLDTRANSFORM, TypeCodes::MODIFYWORLDTRANSFORM,
          TypeCodes::SETMAPMODE, TypeCodes::SETWINDOWEXTEX, TypeCodes::SETWINDOWORGEX,
          TypeCodes::SETVIEWPORTEXTEX, TypeCodes::SETPOLYFILLMODE, TypeCodes::SETROP2,
          TypeCodes::SETSTRETCHBLTMODE, TypeCodes::SETBRUSHORGEX, TypeCodes::SAVEDC,
          TypeCodes::BEGINPATH, TypeCodes::ENDPATH, TypeCodes::CLOSEFIGURE,
          TypeCodes::FILLPATH, TypeCodes::STROKEANDFILLPATH, TypeCodes::STROKEPATH,
          TypeCodes::RECTANGLE, TypeCodes::INTERSECTCLIPRECT, TypeCodes::EXCLUDECLIPRECT,
          TypeCodes::SETMITERLIMIT, TypeCodes::SETICMMODE, TypeCodes::SETLAYOUT
        ].freeze
        BY_TYPE = ENABLED_TYPES.to_h { |type_id| [type_id, new(Records.lookup(type_id))] }.freeze
        BY_CLASS = BY_TYPE.values.to_h { |filler| [filler.wire_class, filler] }.freeze
        private_constant :ENABLED_TYPES, :BY_TYPE, :BY_CLASS
      end
    end
  end
end
