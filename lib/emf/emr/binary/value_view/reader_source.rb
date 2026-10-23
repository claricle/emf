# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      class ValueView
        # Source of the readers of a view: `read_bytes(data, base)`,
        # `read_wire(wire)` and `read_mixed(data, base, wire)`.
        class ReaderSource
          def initialize(layout)
            @layout = layout
          end

          # Source of `read_bytes(data, base)`, `read_wire(wire)` and
          # `read_mixed(data, base, wire)`; each builds the value object from
          # the locals `v0..vN` (unpacked leaves) and `points`, or from the
          # wire's accessors.
          def to_s
            unpack = "#{locals} = data.unpack(#{@layout.leaves.map { |leaf| leaf[:directive] }.join.inspect}, offset: base)"
            <<~RUBY
              def read_bytes(data, base)
                #{unpack}
                #{array_source}
                #{construct(@layout.tree, :bytes, 'wire')}
              end

              def read_wire(wire)
                #{construct(@layout.tree, :wire, 'wire')}
              end

              def read_mixed(data, base, wire)
                #{unpack}
                #{array_source}
                objs = wire.instance_variable_get(:@field_objs)
                #{mixed_construct}
              end
            RUBY
          end

          private

          def locals
            @layout.leaves.each_index.map { |index| "v#{index}" }.join(", ")
          end

          # Source for the local `points` of an array record (nothing for
          # others); the reader returns nil when the count overruns the record.
          def array_source
            array = @layout.array
            return "" unless array

            count = "v#{@layout.count_index}"
            size = @layout.size
            <<~RUBY
              return if #{size} + (#{count} * #{array[:bytes]}) > data.unpack1("V", offset: base + 4) ||
                        base + #{size} + (#{count} * #{array[:bytes]}) > data.bytesize

              flat = data.unpack(#{array[:directive].inspect} + (#{count} * 2).to_s, offset: base + #{size})
              points = Array.new(#{count}) { |i| POINT.new(flat[i * 2], flat[(i * 2) + 1]) }.freeze
            RUBY
          end

          def construct(node, mode, chain)
            return (mode == :bytes ? "v#{node.last}" : "#{chain}.value") if node.first == :leaf
            if node.first == :array
              return (mode == :bytes ? "points" : "#{chain}.map { |point| POINT.new(point.x.value, point.y.value) }.freeze")
            end

            klass, children = node
            args = children.map { |name, child| construct(child, mode, "#{chain}.#{name}") }
            "CLASSES[#{@layout.classes.index(klass)}].new(#{args.join(', ')})"
          end

          # `construct` for the top struct with each field taken from the wire
          # when the shell has made it (its slot in @field_objs is set; a thin shell
          # has no @field_objs and has made none).
          def mixed_construct
            klass, children = @layout.tree
            args = children.each_with_index.map do |(name, child), slot|
              "(objs&.[](#{slot}) ? #{construct(child, :wire, "wire.#{name}")} : #{construct(child, :bytes, '')})"
            end
            "CLASSES[#{@layout.classes.index(klass)}].new(#{args.join(', ')})"
          end
        end
      end
    end
  end
end
