# frozen_string_literal: true

require_relative "pack_plan_check"
require_relative "pack_plan_values"

module Emf
  module Emr
    module Binary
      # The bytes of `klass.new(**attrs)` with n_size set to the record's size,
      # computed straight from the attributes, with no wire built. Compiled once
      # per FastFill class from the instantiated template: the leaves in write
      # order with their defaults, directives and ranges. It accepts only
      # attributes whose BinData assignment is the identity: known fields, and
      # in-range Integers (Floats float32 holds exactly, for float32 leaves) given as a
      # symbol-keyed Hash or an instance of the field's own struct class, plus,
      # for a point array record, a list of integer points. Everything else
      # returns nil and the caller builds the wire.
      #
      # A plan is only used once it reproduces BinData's bytes on the leaf
      # values it was compiled from (see `verified?`); otherwise `build`
      # returns nil for the class.
      class PackPlan
        include PackPlanCheck
        include PackPlanValues

        LEAVES = {
          "BinData::Uint32le" => ["V", 0, (2**32) - 1],
          "BinData::Int32le" => ["l<", -(2**31), (2**31) - 1],
          "BinData::Uint8" => ["C", 0, 255],
          "Emf::Binary::Float32Le" => ["e", nil, nil]
        }.freeze
        private_constant :LEAVES

        Leaf = Struct.new(:index)
        Branch = Struct.new(:klass, :children)

        # A verified plan for the filler's class, or nil.
        def self.build(filler)
          plan = new(filler)
          plan if plan.verified?(filler)
        rescue StandardError
          nil
        end

        def initialize(filler)
          template = filler.template
          @leaves = []
          @defaults = []
          @tree = {}
          @array = nil
          template.field_names.each { |name| @tree[name] = node_of(template.public_send(name), name) }
          @format = @leaves.map(&:first).join
          @size = filler.size
          @n_size = @tree.fetch(:n_size).index
          @coord_bytes = 0
          finish_points(filler)
        end

        # The record's bytes, or nil when any attribute needs BinData.
        def pack(attrs)
          catch(:decline) do
            values = @defaults.dup
            coords = nil
            attrs.each do |name, value|
              node = @tree[name] or throw :decline
              next if value.nil?

              node.equal?(@array) ? coords = coords_of(value) : (store(values, node, value) or throw :decline)
            end
            finish(values, coords)
          end
        end

        private

        def node_of(field, name)
          if field.is_a?(BinData::Array)
            @array_name = name
            return @array = Branch.new(field.class, nil)
          end
          return branch_of(field) if field.respond_to?(:field_names)

          directive, low, high = LEAVES.fetch(field.class.name)
          @leaves << [directive, low, high]
          @defaults << field.value
          Leaf.new(@leaves.size - 1)
        end

        def branch_of(struct)
          children = struct.field_names.to_h { |name| [name, node_of(struct.public_send(name), name)] }
          Branch.new(struct.class, children)
        end

        # The record's one array, which must come last, as `pack` appends it.
        def finish_points(filler)
          return unless @array

          raise ArgumentError, "array is not the last field" unless @tree.keys.last == @array_name

          @point_class, @coord_directive, @coord_low, @coord_high, @coord_bytes, count_name = filler.points_layout
          @count = @tree.fetch(count_name).index
          @points_format = "#{@format}#{@coord_directive}*"
        end

        # The wire read back from the bytes must be the wire BinData built,
        # so the count must be the array's length (an absent array is empty).
        def finish(values, coords)
          throw :decline if @array && values[@count] != (coords ? coords.size / 2 : 0)

          values[@n_size] = @size + (coords ? coords.size * @coord_bytes : 0)
          values.concat(coords) if coords
          values.pack(coords ? @points_format : @format)
        end
      end
    end
  end
end
