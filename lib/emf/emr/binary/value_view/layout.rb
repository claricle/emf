# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      class ValueView
        # The leaf and array layout of one wire class, from a fresh instance.
        class Layout
          # Unpack directive and width of each leaf class.
          LEAVES = {
            "BinData::Uint32le" => ["V", 4],
            "BinData::Int32le" => ["l<", 4],
            "BinData::Uint8" => ["C", 1],
            "Emf::Binary::Float32Le" => ["e", 4]
          }.freeze
          # Unpack directive and element width of each point coordinate class.
          POINTS = {
            "BinData::Int32le" => ["l<", 8],
            "BinData::Int16le" => ["s<", 4]
          }.freeze
          FLOAT = "Emf::Binary::Float32Le"
          private_constant :LEAVES, :POINTS, :FLOAT

          # tree: [value class, [[name, node], ...]]; a leaf node is [:leaf, index], the array [:array].
          # leaves: { directive:, at:, float:, klass: } in wire order.
          # array: { name:, directive:, bytes:, count:, klass: } or nil.
          attr_reader :tree, :leaves, :array, :size, :classes

          def initialize(wire_class)
            @wire_class = wire_class
            @leaves = []
            @classes = []
            @array = nil
            @size = 0
            sample = wire_class.new
            @tree = struct_of(sample)
            raise Unsupported, "layout does not tile" unless sample.num_bytes == @size
          end

          def leaf_paths(node = @tree, prefix = [])
            return [prefix] if node.first == :leaf
            return [] if node.first == :array

            node.last.flat_map { |name, child| leaf_paths(child, prefix + [name]) }
          end

          # Index of the leaf holding the point count.
          def count_index
            slot = @tree.last.assoc(@array[:count])
            raise Unsupported, "count field" unless slot && slot.last.first == :leaf

            slot.last.last
          end

          private

          def struct_of(struct)
            children = struct.field_names.map { |name| [name, child_of(struct.public_send(name), name, struct)] }
            klass = ValueView.value_class(struct.class, children.map(&:first))
            @classes << klass
            [klass, children]
          end

          def child_of(field, name, parent)
            if field.respond_to?(:field_names)
              struct_of(field)
            elsif field.is_a?(BinData::Array)
              array_of(field, name, parent)
            else
              leaf_of(field)
            end
          end

          def leaf_of(field)
            name = field.class.name
            directive, width = LEAVES.fetch(name) { raise Unsupported, "leaf #{field.class}" }
            @leaves << { directive: directive, at: @size, float: FLOAT.eql?(name), klass: name }
            @size += width
            [:leaf, @leaves.size - 1]
          end

          def array_of(field, name, parent)
            raise Unsupported, "second array" if @array || !parent.instance_of?(@wire_class)
            raise Unsupported, "array is not last" unless parent.field_names.last == name

            point = field.send(:new_element)
            directive, bytes = POINTS.fetch(point.x.class.name) { raise Unsupported, "point #{point.x.class}" }
            raise Unsupported, "point members" unless point.field_names == %i[x y] && point.x.instance_of?(point.y.class)

            count = field.send(:get_parameter, :initial_length)
            raise Unsupported, "array count" unless count.is_a?(Symbol)

            @array = { name: name, directive: directive, bytes: bytes, count: count,
                       klass: ValueView.value_class(point.class, %i[x y]) }
            [:array]
          end
        end
      end
    end
  end
end
