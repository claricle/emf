# frozen_string_literal: true

require "stringio"
require "bindata"
require "emf/emf_plus/records/primitives/byte_reader"
require "emf/emf_plus/records/primitives/rect_f"
require "emf/emf_plus/records/primitives/region_node_child_nodes"
require "emf/emf_plus/records/primitives/region_node_path"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRegionNode (2.2.2.40): a RegionNodeDataType, then data chosen
        # by it: two child nodes (And/Or/Xor/Exclude/Complement), a RectF, a
        # RegionNodePath, or nothing (Empty/Infinite).
        class RegionNode
          include ByteReader

          COMBINING = [0x1, 0x2, 0x3, 0x4, 0x5].freeze
          RECT = 0x10000000
          PATH = 0x10000001
          EMPTY = 0x10000002
          INFINITE = 0x10000003
          MAX_DEPTH = 256

          attr_reader :type, :data

          def initialize(depth = 0)
            @depth = depth
          end

          def read(io)
            raise BinData::ValidityError, "region nodes nested deeper than #{MAX_DEPTH} levels" if @depth > MAX_DEPTH

            @type = take(io, 4, "RegionNode Type").unpack1("V")
            @data = read_data(io)
            self
          end

          def combining? = COMBINING.include?(type)
          def to_binary_s = [type].pack("V") + (data ? data.to_binary_s : "".b)

          # Nodes in this subtree, itself included.
          def node_count = 1 + (combining? ? data.left.node_count + data.right.node_count : 0)

          private

          def read_data(io)
            case type
            when *COMBINING then read_children(io)
            when RECT then RectF.new.read(io)
            when PATH then RegionNodePath.new.read(io)
            when EMPTY, INFINITE then nil
            else raise BinData::ValidityError, "unknown RegionNodeDataType 0x#{type.to_s(16)}"
            end
          end

          def read_children(io)
            RegionNodeChildNodes.new(child(io), child(io))
          end

          def child(io) = self.class.new(@depth + 1).read(io)
        end
      end
    end
  end
end
