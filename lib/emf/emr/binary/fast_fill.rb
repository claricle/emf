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
        EMPTY_SUFFIX = "".b.freeze
        private_constant :DIRECTIVES, :EMPTY_SUFFIX

        def self.for(type_id)
          BY_TYPE[type_id]
        end

        attr_reader :size

        def initialize(klass)
          @klass = klass
          sample = klass.new
          @size = sample.num_bytes
          leaves = leaf_paths(sample, [])
          @format = leaves.map { |_, field| DIRECTIVES.fetch(field.name) }.join
          @setters = leaves.map { |path, field| setter_for(path, field) }.freeze
        end

        def call(record_bytes)
          wire = @klass.new
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

        private

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
          TypeCodes::SETWORLDTRANSFORM, TypeCodes::MODIFYWORLDTRANSFORM
        ].freeze
        BY_TYPE = ENABLED_TYPES.to_h { |type_id| [type_id, new(Records.lookup(type_id))] }.freeze
        private_constant :ENABLED_TYPES, :BY_TYPE
      end
    end
  end
end
