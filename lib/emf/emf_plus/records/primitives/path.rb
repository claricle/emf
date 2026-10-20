# frozen_string_literal: true

require "stringio"
require "emf/emf_plus/records/primitives/byte_reader"
require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/path_point_type"
require "emf/emf_plus/records/primitives/path_point_type_rle"
require "emf/emf_plus/records/primitives/point_array"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPath (2.2.1.6) without its AlignmentPadding, which the caller
        # keeps. Same surface as a BinData record (`read`, `num_bytes`,
        # `to_binary_s`); hand-parsed because the point and type encodings are
        # chosen by the flags and the RLE run list has no stored length.
        class Path
          include ByteReader

          RELATIVE_FLAG = 0x0800
          COMPRESSED_FLAG = 0x4000
          HEADER_SIZE = 12
          MIN_POINT_SIZE = { relative: 2, compressed: 4, float: 8 }.freeze
          private_constant :MIN_POINT_SIZE

          attr_reader :version, :point_count, :flags, :points, :point_types

          def read(source)
            io = StringIO.new(source)
            @version = GraphicsVersion.new.read(io)
            @point_count, @flags = take(io, 8, "PathPointCount and PathPointFlags").unpack("VV")
            require_room(io)
            @points = PointArray.new(point_count: point_count, relative: relative?, compressed: compressed?).read(io)
            @point_types = relative? ? read_runs(io) : read_types(io)
            @size = io.pos
            self
          end

          def relative? = flags.anybits?(RELATIVE_FLAG)
          # The C flag is undefined, and ignored, when R is set.
          def compressed? = !relative? && flags.anybits?(COMPRESSED_FLAG)
          def num_bytes = @size

          def to_binary_s
            version.to_binary_s + [point_count, flags].pack("VV") + points.to_binary_s +
              point_types.map(&:to_binary_s).join
          end

          private

          def point_kind
            if relative? then :relative
            elsif compressed? then :compressed
            else :float
            end
          end

          def require_room(io)
            needed = (point_count * MIN_POINT_SIZE.fetch(point_kind)) + min_type_bytes
            return if needed <= remaining(io)

            raise EOFError, "#{point_count} path points need at least #{needed} bytes, #{remaining(io)} left"
          end

          def min_type_bytes
            return point_count unless relative?

            point_count.zero? ? 0 : PathPointTypeRLE.new.num_bytes
          end

          def read_types(io)
            Array.new(point_count) { PathPointType.new.read(io) }
          end

          def read_runs(io)
            covered = 0
            runs = []
            while covered < point_count
              runs << PathPointTypeRLE.new.read(io)
              covered += runs.last.run_count
            end
            runs
          end
        end
      end
    end
  end
end
