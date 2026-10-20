# frozen_string_literal: true

require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/transform_matrix"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusPen (2.2.1.7): Version, Type, PenData (2.2.2.33) with the
      # optional data its flags select (2.2.2.34), then an EmfPlusBrush.
      # The brush reads to the end of the object, so alignment padding is in
      # the brush's `trailing`.
      class Pen < Typed
        DATA_TRANSFORM = 0x001
        DATA_START_CAP = 0x002
        DATA_END_CAP = 0x004
        DATA_JOIN = 0x008
        DATA_MITER_LIMIT = 0x010
        DATA_LINE_STYLE = 0x020
        DATA_DASHED_LINE_CAP = 0x040
        DATA_DASH_OFFSET = 0x080
        DATA_DASHED_LINE = 0x100
        DATA_NON_CENTER = 0x200
        DATA_COMPOUND_LINE = 0x400
        DATA_CUSTOM_START_CAP = 0x800
        DATA_CUSTOM_END_CAP = 0x1000

        P = Records::Primitives
        private_constant :P

        class PenHeader < BinData::Record
          endian :little
          graphics_version :version
          uint32 :pen_type
          uint32 :pen_data_flags
          uint32 :pen_unit
          float :pen_width
        end

        # EmfPlusDashedLineData (2.2.2.16).
        class DashedLineData < BinData::Record
          endian :little
          uint32 :dashed_line_data_size
          array :dashed_line_data, type: :float_le, initial_length: :dashed_line_data_size
        end

        # EmfPlusCompoundLineData (2.2.2.9).
        class CompoundLineData < BinData::Record
          endian :little
          uint32 :compound_line_data_size
          array :compound_line_data, type: :float_le, initial_length: :compound_line_data_size
        end

        # Optional scalars in spec order: flag, part name, BinData type.
        SCALARS = [
          [DATA_START_CAP, :start_cap, BinData::Int32le],
          [DATA_END_CAP, :end_cap, BinData::Int32le],
          [DATA_JOIN, :join, BinData::Int32le],
          [DATA_MITER_LIMIT, :miter_limit, BinData::FloatLe],
          [DATA_LINE_STYLE, :line_style, BinData::Int32le],
          [DATA_DASHED_LINE_CAP, :dashed_line_cap, BinData::Int32le],
          [DATA_DASH_OFFSET, :dash_offset, BinData::FloatLe]
        ].freeze
        private_constant :SCALARS

        # Walks the data once, reading each piece the flags select.
        class Reader
          def initialize(data, logical)
            @cursor = Parts::Cursor.new(data)
            @logical = logical
          end

          def read
            @cursor.take(:header, PenHeader)
            read_optional(@cursor.parts.fetch(:header).pen_data_flags)
            @cursor.parts[:brush] = Parts::Nested.new(Brush.new(slice(BRUSH, @cursor.rest)))
            Parts::Body.new(@cursor.parts)
          end

          private

          def read_optional(flags)
            @cursor.take(:transform, P::TransformMatrix) if flags.anybits?(DATA_TRANSFORM)
            SCALARS.each { |flag, name, type| @cursor.take(name, type) if flags.anybits?(flag) }
            @cursor.take_counted(:dashed_line, DashedLineData, 4) if flags.anybits?(DATA_DASHED_LINE)
            @cursor.take(:pen_alignment, BinData::Int32le) if flags.anybits?(DATA_NON_CENTER)
            @cursor.take_counted(:compound_line, CompoundLineData, 4) if flags.anybits?(DATA_COMPOUND_LINE)
            read_custom_cap(:custom_start_cap) if flags.anybits?(DATA_CUSTOM_START_CAP)
            read_custom_cap(:custom_end_cap) if flags.anybits?(DATA_CUSTOM_END_CAP)
          end

          def read_custom_cap(name)
            @cursor.take_sized(name) { |bytes| Parts::Nested.new(CustomLineCap.new(slice(CUSTOM_LINE_CAP, bytes))) }
          end

          def slice(object_type, bytes) = Parts::Slice.new(object_type, bytes, @logical.offset)
        end

        def pen_type = header.pen_type
        def pen_data_flags = header.pen_data_flags
        def pen_unit = header.pen_unit
        def pen_width = header.pen_width
        def transform = body.parts[:transform]
        def start_cap = scalar(:start_cap)
        def end_cap = scalar(:end_cap)
        def join = scalar(:join)
        def miter_limit = scalar(:miter_limit)
        def line_style = scalar(:line_style)
        def dashed_line_cap = scalar(:dashed_line_cap)
        def dash_offset = scalar(:dash_offset)
        def pen_alignment = scalar(:pen_alignment)
        def dashed_line = body.parts[:dashed_line]&.dashed_line_data&.to_a
        def compound_line = body.parts[:compound_line]&.compound_line_data&.to_a
        def custom_start_cap = body.parts[:custom_start_cap]&.inner&.object
        def custom_end_cap = body.parts[:custom_end_cap]&.inner&.object
        def brush = body.parts.fetch(:brush).object

        private

        def header = body.parts.fetch(:header)
        def scalar(name) = body.parts[name]&.value

        def read_body(data, logical)
          Reader.new(data, logical).read
        rescue IOError, BinData::ValidityError, Parts::Malformed => e
          fail_parse(logical, e.message)
        end
      end
    end
  end
end
