# frozen_string_literal: true

require "stringio"
require "emf/emf_plus/records/primitives/byte_reader"
require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/region_node"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusRegion object (2.2.1.8). The RegionNode array of the spec is a
      # preorder binary tree, so one root node holds all RegionNodeCount + 1
      # nodes; bytes after the root stay in `trailing`.
      class Region < Typed
        class RegionBody
          include Records::Primitives::ByteReader

          attr_reader :version, :region_node_count, :root

          def read(source)
            io = StringIO.new(source)
            @version = Records::Primitives::GraphicsVersion.new.read(io)
            @region_node_count = take(io, 4, "RegionNodeCount").unpack1("V")
            @root = Records::Primitives::RegionNode.new.read(io)
            @size = io.pos
            self
          end

          def num_bytes = @size
          def to_binary_s = version.to_binary_s + [region_node_count].pack("V") + root.to_binary_s
        end
        BODY = RegionBody

        def node_count = body.region_node_count
        def root = body.root
      end
    end
  end
end
