# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/argb"
require "emf/emf_plus/records/primitives/point_f"
require "emf/emf_plus/records/primitives/rect_f"
require "emf/emf_plus/records/primitives/transform_matrix"
require "emf/emf_plus/records/primitives/blend_colors"
require "emf/emf_plus/records/primitives/blend_factors"
require "emf/emf_plus/records/primitives/focus_scale_data"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusBrush (2.2.1.1): Version, Type, then the BrushData the Type
      # selects. Every count is checked against the bytes left before BinData
      # allocates, so a hostile count cannot hang or exhaust memory.
      #
      # The nested EmfPlusPath of a path gradient boundary (BoundaryPathData)
      # and the EmfPlusImage of a texture brush decode through the Path and
      # Image objects. A nested body that does not parse stays raw bytes, so
      # the brush still round-trips.
      class Brush < Typed
        SOLID = 0
        HATCH = 1
        TEXTURE = 2
        PATH_GRADIENT = 3
        LINEAR_GRADIENT = 4

        DATA_PATH = 0x01
        DATA_TRANSFORM = 0x02
        DATA_PRESET_COLORS = 0x04
        DATA_BLEND_FACTORS_H = 0x08
        DATA_BLEND_FACTORS_V = 0x10
        DATA_FOCUS_SCALES = 0x40

        P = Records::Primitives
        private_constant :P

        class BrushHeader < Records::Body
          endian :little
          graphics_version :version
          uint32 :brush_type
        end

        # EmfPlusSolidBrushData (2.2.2.43).
        class SolidBrushData < Records::Body
          endian :little
          argb :solid_color
        end

        # EmfPlusHatchBrushData (2.2.2.20).
        class HatchBrushData < Records::Body
          endian :little
          uint32 :hatch_style
          argb :fore_color
          argb :back_color
        end

        # EmfPlusTextureBrushData (2.2.2.45) without OptionalData.
        class TextureBrushData < Records::Body
          endian :little
          uint32 :brush_data_flags
          int32 :wrap_mode
        end

        # EmfPlusLinearGradientBrushData (2.2.2.24) without OptionalData.
        class LinearGradientBrushData < Records::Body
          endian :little
          uint32 :brush_data_flags
          int32 :wrap_mode
          rect_f :rect_f
          argb :start_color
          argb :end_color
          uint32 :reserved1
          uint32 :reserved2
        end

        # EmfPlusPathGradientBrushData (2.2.2.29) up to SurroundingColorCount.
        class PathGradientBrushData < Records::Body
          endian :little
          uint32 :brush_data_flags
          int32 :wrap_mode
          argb :center_color
          point_f :center_point_f
        end

        class SurroundingColors < Records::Body
          endian :little
          uint32 :surrounding_color_count
          array :surrounding_color, type: :argb, initial_length: :surrounding_color_count
        end

        # EmfPlusBoundaryPathData (2.2.2.6).
        class BoundaryPathData < Records::Body
          endian :little
          int32 :boundary_path_size
          string :boundary_path_data, read_length: :boundary_path_size
        end

        # EmfPlusBoundaryPointData (2.2.2.7).
        class BoundaryPointData < Records::Body
          endian :little
          int32 :boundary_point_count
          array :boundary_point_data, type: :point_f, initial_length: :boundary_point_count
        end

        class Malformed < StandardError; end
        private_constant :Malformed

        module Nested
          Source = Struct.new(:object_type, :data, :offset)

          module_function

          # The decoded nested object, or nil when its bytes do not parse.
          def decode(klass, object_type, data)
            klass.new(Source.new(object_type, data, 0))
          rescue Emf::ParseError
            nil
          end
        end
        private_constant :Nested

        # BoundaryPathData with its EmfPlusPath decoded. Size and bytes follow
        # the path, so an edit to it re-serializes with the right size.
        class BoundaryPath
          attr_reader :path

          def initialize(record)
            @raw = record.boundary_path_data.to_s.b.freeze
            @path = Nested.decode(Path, PATH, @raw)
          end

          def boundary_path_data = path ? path.to_binary : @raw
          def boundary_path_size = boundary_path_data.bytesize
          def to_binary_s = [boundary_path_size].pack("l<") + boundary_path_data
          def num_bytes = 4 + boundary_path_size
        end

        # Ordered pieces of the object; strings are raw nested objects.
        class Body
          attr_reader :parts

          def initialize(parts) = @parts = parts

          def version = parts.fetch(:header).version

          def num_bytes = parts.each_value.sum { |part| bytes(part).bytesize }

          def to_binary_s = parts.each_value.map { |part| bytes(part) }.join.b

          private

          def bytes(part)
            case part
            when String then part
            when Typed then part.to_binary
            else part.to_binary_s
            end
          end
        end

        # Walks the data once, reading each piece the flags select.
        class Reader
          def initialize(data)
            @data = data
            @pos = 0
            @parts = {}
          end

          def read
            take(:header, BrushHeader)
            read_brush_data(@parts.fetch(:header).brush_type)
            Body.new(@parts)
          end

          private

          def read_brush_data(brush_type)
            case brush_type
            when SOLID then take(:data, SolidBrushData)
            when HATCH then take(:data, HatchBrushData)
            when TEXTURE then read_texture
            when PATH_GRADIENT then read_path_gradient
            when LINEAR_GRADIENT then read_linear_gradient
            else take_rest(:unknown_data)
            end
          end

          def read_texture
            take(:data, TextureBrushData)
            take(:transform, P::TransformMatrix) if flag?(DATA_TRANSFORM)
            take_rest(:image)
            decode_image
          end

          def decode_image
            raw = @parts[:image]
            return unless raw

            @parts[:image] = Nested.decode(Image, IMAGE, raw) || raw
          end

          def read_linear_gradient
            take(:data, LinearGradientBrushData)
            take(:transform, P::TransformMatrix) if flag?(DATA_TRANSFORM)
            if flag?(DATA_PRESET_COLORS)
              take_counted(:blend_colors, P::BlendColors, 8)
            else
              # The spec lists the vertical pattern before the horizontal one.
              take_counted(:blend_factors_v, P::BlendFactors, 8) if flag?(DATA_BLEND_FACTORS_V)
              take_counted(:blend_factors_h, P::BlendFactors, 8) if flag?(DATA_BLEND_FACTORS_H)
            end
          end

          def read_path_gradient
            take(:data, PathGradientBrushData)
            take_counted(:surrounding_colors, SurroundingColors, 4)
            flag?(DATA_PATH) ? read_boundary_path : take_counted(:boundary_points, BoundaryPointData, 8, signed: true)
            read_path_gradient_optional
          end

          def read_boundary_path
            take_counted(:boundary_path, BoundaryPathData, 1, signed: true)
            @parts[:boundary_path] = BoundaryPath.new(@parts[:boundary_path])
          end

          def read_path_gradient_optional
            take(:transform, P::TransformMatrix) if flag?(DATA_TRANSFORM)
            if flag?(DATA_PRESET_COLORS)
              take_counted(:blend_colors, P::BlendColors, 8)
            elsif flag?(DATA_BLEND_FACTORS_H)
              take_counted(:blend_factors_h, P::BlendFactors, 8)
            end
            take(:focus_scales, P::FocusScaleData) if flag?(DATA_FOCUS_SCALES)
          end

          def flag?(mask) = @parts.fetch(:data).brush_data_flags.anybits?(mask)

          def take(name, klass)
            record = klass.new
            raise Malformed, "#{name} needs #{record.num_bytes} bytes, #{remaining} left" if record.num_bytes > remaining

            @parts[name] = record.read(@data.byteslice(@pos..))
            @pos += record.num_bytes
          end

          # `item_size` bytes per counted element after the 4-byte count.
          def take_counted(name, klass, item_size, signed: false)
            raise Malformed, "#{name} count needs 4 bytes, #{remaining} left" if remaining < 4

            count = @data.byteslice(@pos, 4).unpack1(signed ? "l<" : "V")
            raise Malformed, "#{name} count #{count} is negative" if count.negative?

            needed = 4 + (count * item_size)
            raise Malformed, "#{name} of #{count} entries needs #{needed} bytes, #{remaining} left" if needed > remaining

            @parts[name] = klass.read(@data.byteslice(@pos..))
            @pos += @parts[name].num_bytes
          end

          def take_rest(name)
            rest = @data.byteslice(@pos..)
            @parts[name] = rest.freeze unless rest.empty?
            @pos += rest.bytesize
          end

          def remaining = @data.bytesize - @pos
        end

        def brush_type = body.parts.fetch(:header).brush_type
        def data = body.parts[:data]
        def brush_data_flags = data.brush_data_flags
        def transform = body.parts[:transform]
        def surrounding_colors = body.parts[:surrounding_colors]
        def boundary_path = body.parts[:boundary_path]
        def boundary_points = body.parts[:boundary_points]
        def blend_colors = body.parts[:blend_colors]
        def blend_factors_h = body.parts[:blend_factors_h]
        def blend_factors_v = body.parts[:blend_factors_v]
        def focus_scales = body.parts[:focus_scales]
        def image = body.parts[:image]
        def unknown_data = body.parts[:unknown_data]

        private

        def read_body(data, logical)
          Reader.new(data).read
        rescue IOError, BinData::ValidityError, Malformed => e
          fail_parse(logical, e.message)
        end
      end
    end
  end
end
