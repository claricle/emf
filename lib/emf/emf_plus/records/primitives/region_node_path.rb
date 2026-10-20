# frozen_string_literal: true

require "stringio"
require "emf/emf_plus/records/primitives/byte_reader"
require "emf/emf_plus/records/primitives/path"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRegionNodePath (2.2.2.42): a byte length, then an EmfPlusPath
        # filling it. Bytes of the length the path does not use (its
        # alignment padding) stay in `padding`.
        class RegionNodePath
          include ByteReader

          attr_reader :path, :padding

          def read(io)
            length = take(io, 4, "RegionNodePathLength").unpack1("l<")
            raise BinData::ValidityError, "negative RegionNodePathLength #{length}" if length.negative?

            bytes = take(io, length, "RegionNodePath of #{length} bytes")
            @path = Path.new.read(bytes)
            @padding = bytes.byteslice(path.num_bytes..)
            self
          end

          def to_binary_s
            body = path.to_binary_s + padding
            [body.bytesize].pack("V") + body
          end
        end
      end
    end
  end
end
