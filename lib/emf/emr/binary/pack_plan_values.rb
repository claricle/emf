# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Which attribute values a PackPlan takes: only those BinData stores
      # unchanged, so the wire read back from the bytes is the wire it built.
      module PackPlanValues
        private

        def store(values, node, value)
          case node
          when PackPlan::Leaf then store_leaf(values, node.index, value)
          else store_branch(values, node, value)
          end
        end

        def store_leaf(values, index, value)
          low = @lows[index]
          if low
            return unless value.instance_of?(Integer) && value >= low && value <= @highs[index]
          else
            return unless float32_exact?(value)
          end
          values[index] = value
        end

        # A Float a float32 leaf stores unchanged: it reads back as the same
        # bits (so not NaN, not past float32 range, not rounded).
        def float32_exact?(value)
          value.instance_of?(Float) && [value].pack("E") == [[value].pack("e").unpack1("e")].pack("E")
        end

        def store_branch(values, node, value)
          if value.instance_of?(Hash)
            value.each do |name, leaf|
              child = node.children[name] or return false
              next if leaf.nil?

              store(values, child, leaf) or return false
            end
            true
          elsif value.instance_of?(node.klass)
            node.children.all? { |name, child| store_from(values, child, value.public_send(name)) }
          else
            false
          end
        end

        def store_from(values, node, source)
          return store_branch_from(values, node, source) if node.is_a?(PackPlan::Branch)

          store_leaf(values, node.index, source.snapshot)
        end

        def store_branch_from(values, node, source)
          node.children.all? { |name, child| store_from(values, child, source.public_send(name)) }
        end

        # Flat coordinates of an Array of {x:, y:} Hashes or points of the
        # record's point class, all Integers in the point range; else declines.
        # Each point is read in place: no per-point pair is allocated.
        def coords_of(points)
          throw :decline unless points.instance_of?(Array)

          coords = []
          points.each do |point|
            if point.instance_of?(Hash)
              throw :decline unless point.size == 2

              x = point[:x]
              y = point[:y]
            elsif point.instance_of?(@point_class)
              x = point.x.snapshot
              y = point.y.snapshot
            else
              throw :decline
            end
            throw :decline unless in_point_range?(x) && in_point_range?(y)

            coords << x << y
          end
          coords
        end

        def in_point_range?(value)
          value.instance_of?(Integer) && value >= @coord_low && value <= @coord_high
        end
      end
    end
  end
end
