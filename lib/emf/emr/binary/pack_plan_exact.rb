# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # The common call shape of `pack`, compiled to one boolean chain: every
      # field but n_size given, nested structs and the point list as plain
      # Hashes and Arrays of Hashes of in-range Integers (or exact Floats). A
      # Hash with exactly as many keys as the struct has fields, every field
      # read non-nil, has exactly the struct's keys, so no per-key bookkeeping
      # is needed; the first value that is not plain makes the chain false and
      # `pack` continues with the general path, which stays the authority on
      # declines and results.
      module PackPlanExact
        private

        # The source of the `if` that returns the exact shape's bytes, or ""
        # when the record has no n_size to leave out.
        def gen_exact
          return "" unless @tree.key?(:n_size)

          @exact_depth = 0
          given = @tree.except(:n_size)
          checks = given.map { |name, node| exact_check(name, node, "attrs") }
          checks.unshift("attrs.size == #{given.size}", "attrs[:n_size].nil?")
          <<~RUBY.gsub(/^(?=.)/, "  ")
            if #{checks.join(" &&\n    ")}
              v#{@n_size} = #{exact_size}
              vals = [#{(0...@leaves.size).map { |index| "v#{index}" }.join(', ')}]
            #{exact_return}end
          RUBY
        end

        def exact_size
          bytes = @array ? " + pts.size * #{@coord_bytes * 2}" : ""
          "size ? #{@size}#{bytes} : #{@defaults[@n_size].inspect}"
        end

        def exact_return
          return "  return vals.pack(#{@format.inspect})\n" unless @array

          "  return vals.pack(#{@points_format.inspect}) if points_appended?(vals, pts)\n"
        end

        def exact_check(name, node, container)
          read = "#{container}[#{name.inspect}]"
          return exact_array(read) if node.equal?(@array)
          return exact_leaf(node.index, read) if node.is_a?(PackPlan::Leaf)

          sub = "h#{@exact_depth += 1}"
          hash = ["#{sub}.instance_of?(Hash)", "#{sub}.size == #{node.children.size}"] +
                 node.children.map { |child, n| exact_check(child, n, sub) }
          return "((#{sub} = #{read}).instance_of?(Hash) &&\n    #{hash.drop(1).join(" &&\n    ")})" unless @plain_leaves

          "((#{sub} = #{read}; #{hash.first}) &&\n    #{hash.drop(1).join(" &&\n    ")} ||\n    #{exact_struct(sub, node)})"
        end

        # A nested struct given as an instance of its own class: its leaves
        # are read from the field objects' stored values, in field order.
        # An unmade field, or a value not stored as a plain Integer or
        # Float, makes the chain false.
        def exact_struct(sub, node)
          @gen_classes << node.klass
          fields = "f#{sub}"
          checks = node.children.each_with_index.map do |(_, child), at|
            if child.is_a?(PackPlan::Leaf)
              exact_leaf(child.index, "#{fields}[#{at}]&.instance_variable_get(:@value)")
            else
              exact_nested_struct(child, "#{fields}[#{at}]")
            end
          end
          ["#{sub}.instance_of?(@gen_classes[#{@gen_classes.size - 1}])",
           "(#{fields} = #{sub}.instance_variable_get(:@field_objs))", *checks].join(" &&\n    ")
        end

        def exact_nested_struct(node, read)
          sub = "h#{@exact_depth += 1}"
          "(#{sub} = #{read}) && #{exact_struct(sub, node)}"
        end

        def exact_array(read)
          "(pts = #{read}).instance_of?(Array) &&\n    v#{@count} == pts.size"
        end

        def exact_leaf(index, read)
          var = "v#{index}"
          low = @lows[index]
          return "float32_exact?(#{var} = #{read})" unless low

          "(#{var} = #{read}).instance_of?(Integer) &&\n    #{var} >= #{low} && #{var} <= #{@highs[index]}"
        end

        # Appends the flat coordinates of `points`, which must each be a
        # Hash of exactly x and y, or a plain point struct, in the point
        # range; false for any other point, with `vals` then to be dropped.
        def points_appended?(vals, points)
          index = 0
          count = points.size
          while index < count
            point = points[index]
            appended = point.instance_of?(Hash) ? hash_point_appended?(vals, point) : struct_point_appended?(vals, point)
            return false unless appended

            index += 1
          end
          true
        end

        def hash_point_appended?(vals, point)
          point.size == 2 && point_appended?(vals, point[:x], point[:y])
        end

        def struct_point_appended?(vals, point)
          return false unless @plain_leaves && point.instance_of?(@point_class)

          fields = point.instance_variable_get(:@field_objs) or return false
          point_appended?(vals, fields[0]&.instance_variable_get(:@value), fields[1]&.instance_variable_get(:@value))
        end

        def point_appended?(vals, x, y)
          return false unless x.instance_of?(Integer) && x >= @coord_low && x <= @coord_high &&
                              y.instance_of?(Integer) && y >= @coord_low && y <= @coord_high

          vals << x << y
          true
        end
      end
    end
  end
end
