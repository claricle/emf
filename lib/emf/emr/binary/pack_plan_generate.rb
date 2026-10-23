# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Straight-line `pack` for a PackPlan: one local per leaf, inline range
      # checks, one Array#pack with a frozen format. It takes only symbol-keyed
      # Hashes of known, in-range, non-nil values (nested structs as Hashes or
      # as instances of their own class; the record's array as the plan takes
      # it); for anything else (unknown keys, nil values, bad values) it hands
      # the call to `pack_interpreted`, so declines and results stay the
      # interpreter's.
      module PackPlanGenerate
        FALLBACK = "return pack_interpreted(attrs, size: size)"
        private_constant :FALLBACK

        private

        def generate_pack
          @gen_depth = 0
          @gen_classes = []
          fields = @tree.reject { |_, node| node.equal?(@array) }
          body = fields.map { |name, node| gen_node(name, node, "attrs", "seen", "  ") }.join
          values = (0...@leaves.size).map { |index| "v#{index}" }
          values << "*coords" if @array
          format = (@array ? @points_format : @format).inspect
          # def pack(attrs, size: true)
          #   seen = 0
          #   <one read-and-check block per field>
          #   return pack_interpreted(attrs, size: size) unless seen == attrs.size
          #   v1 = <size> if size
          #   [v0, v1, ...].pack("<frozen format>")
          # end
          source = <<~RUBY
            def pack(attrs, size: true)
              seen = 0
            #{body}#{gen_array}  #{FALLBACK} unless seen == attrs.size

            #{gen_size}  [#{values.join(', ')}].pack(#{format})
            end
          RUBY
          singleton_class.class_eval(source, __FILE__, __LINE__)
        end

        def gen_array
          return "" unless @array

          <<~RUBY.gsub(/^(?=.)/, "  ")
            coords = attrs[#{@array_name.inspect}]
            unless coords.nil?
              seen += 1
              coords = catch(:decline) { coords_of(coords) } or #{FALLBACK}
            end
            #{FALLBACK} unless v#{@count} == (coords ? coords.size / 2 : 0)
          RUBY
        end

        def gen_size
          bytes = @array ? " + (coords ? coords.size * #{@coord_bytes} : 0)" : ""
          "  v#{@n_size} = #{@size}#{bytes} if size\n"
        end

        def gen_node(name, node, container, counter, indent)
          return gen_leaf(gen_read(container, name, indent), node.index, counter, indent) if node.is_a?(PackPlan::Leaf)

          sub = "h#{@gen_depth += 1}"
          @gen_classes << node.klass
          klass = "@gen_classes[#{@gen_classes.size - 1}]"
          inner = node.children.map { |child, n| gen_node(child, n, sub, "#{sub}_seen", "#{indent}  ") }.join
          "#{indent}#{sub} = #{container}[#{name.inspect}]\n" \
            "#{indent}if #{sub}.instance_of?(#{klass})\n#{indent}  #{counter} += 1\n#{gen_from(node, sub, "#{indent}  ")}" \
            "#{indent}else\n#{gen_hash(sub, counter, inner, indent)}#{indent}end\n"
        end

        def gen_hash(sub, counter, inner, indent)
          "#{indent}  if #{sub}.nil? then #{sub} = {}\n" \
            "#{indent}  elsif #{sub}.instance_of?(Hash) then #{counter} += 1\n" \
            "#{indent}  else #{FALLBACK}\n#{indent}  end\n" \
            "#{indent}  #{sub}_seen = 0\n#{inner}" \
            "#{indent}  #{FALLBACK} unless #{sub}_seen == #{sub}.size\n"
        end

        # The leaves of a struct instance, read through `snapshot`.
        def gen_from(branch, source, indent)
          branch.children.map do |name, node|
            if node.is_a?(PackPlan::Leaf)
              gen_leaf("#{indent}v#{node.index} = #{source}.#{name}.snapshot\n", node.index, nil, indent)
            else
              gen_from(node, "#{source}.#{name}", indent)
            end
          end.join
        end

        def gen_read(container, name, indent) = "#{indent}v = #{container}[#{name.inspect}]\n"

        def gen_leaf(read, index, counter, indent)
          var = "v#{index}"
          read = read.sub(/\bv = /, "#{var} = ")
          return "#{read}#{indent}#{FALLBACK} unless #{gen_valid(var, index)}\n" unless counter

          "#{read}#{indent}if #{var}.nil? then #{var} = #{@defaults[index].inspect}\n" \
            "#{indent}elsif #{gen_valid(var, index)} then #{counter} += 1\n" \
            "#{indent}else #{FALLBACK}\n#{indent}end\n"
        end

        def gen_valid(var, index)
          low = @lows[index]
          return "float32_exact?(#{var})" unless low

          "#{var}.instance_of?(Integer) && #{var} >= #{low} && #{var} <= #{@highs[index]}"
        end
      end
    end
  end
end
