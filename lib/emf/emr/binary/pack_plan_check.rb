# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      # The self-check of a PackPlan: its bytes against BinData's.
      module PackPlanCheck
        # True when the plan's bytes equal BinData's for the defaults, for every
        # leaf set alone, and for every leaf set at once.
        def verified?(filler)
          klass = filler.wire_class
          cases = [{}] + each_leaf_attrs + [all_leaf_attrs]
          cases << { @array_name => [{ x: 3, y: -4 }, { x: 5, y: 6 }] } if @array
          return false unless pack({})

          # A plan may decline a case (nil) but never differ from BinData.
          cases.all? { |attrs| (bytes = pack(attrs)).nil? || bytes == reference(klass, attrs) }
        end

        private

        # BinData's own constructor: Record.new would consult this plan.
        BINDATA_NEW = BinData::Base.method(:new).unbind
        private_constant :BINDATA_NEW

        def reference(klass, attrs)
          wire = BINDATA_NEW.bind_call(klass, **attrs)
          wire.n_size = wire.num_bytes
          wire.to_binary_s
        end

        def each_leaf_attrs
          @tree.filter_map do |name, node|
            next if node.equal?(@array)

            { name => sample_value(node, 1) }
          end
        end

        def all_leaf_attrs
          @tree.reject { |_, node| node.equal?(@array) }.to_h { |name, node| [name, sample_value(node, 7)] }
        end

        # Hash of distinct in-range values for a field.
        def sample_value(node, seed)
          return leaf_sample(node.index, seed) if node.is_a?(PackPlan::Leaf)

          node.children.each_with_index.to_h { |(name, child), at| [name, sample_value(child, seed + at + 1)] }
        end

        def leaf_sample(index, seed)
          _, low, high = @leaves[index]
          return seed + 0.5 unless low # exact in float32

          (seed * 3).clamp(low, high)
        end
      end
    end
  end
end
