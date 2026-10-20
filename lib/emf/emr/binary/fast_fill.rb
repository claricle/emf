# frozen_string_literal: true

module Emf
  module Emr
    module Binary
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
          @format = leaves.map { |_, field| DIRECTIVES.fetch(field.name) }.join
          # Float layouts are not packed: measured on test-000, BinData writes
          # SETWORLDTRANSFORM in 15 objects against 18+ for a value pack, and
          # Float32Le must write its retained NaN bits itself.
          @pack_format = @format unless leaves.any? { |_, field| float?(field) }
          @value_readers = leaves.map { |path, _| path.freeze }.freeze
          @setters = leaves.map { |path, field| setter_for(path, field) }.freeze
        end

        def call(record_bytes)
          wire = @wire_class.new
          values = record_bytes.unpack(@format)
          i = 0
          while i < @setters.size
            getters, setter = @setters[i]
            target = wire
            getters.each { |getter| target = target.public_send(getter) }
            target.public_send(setter, values[i])
            i += 1
          end
          [wire, suffix(record_bytes)]
        end

        # Bytes of the fixed layout, equal to wire.to_binary_s, or nil for a
        # float layout (the caller falls back to BinData). Values are read
        # from the live leaves, so edits are reflected; BinData clamps integers
        # on assignment, so the stored values are always in range.
        def pack(wire)
          return unless @pack_format

          @value_readers.map { |path| path.inject(wire) { |target, getter| target.public_send(getter) }.value }.pack(@pack_format)
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

        def setter_for(path, field_class)
          return [path, :assign_bits] if field_class == Emf::Binary::Float32Le

          [path[0..-2], :"#{path.last}="]
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
