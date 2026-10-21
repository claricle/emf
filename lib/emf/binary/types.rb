# frozen_string_literal: true

require "bindata"
require "emf/binary/class_field_accessors"
require "emf/binary/float32_le"

module Emf
  module Binary
    # `Type.new(x: 1, y: 2)` for an all-integer layout copies one instantiated
    # sample and assigns the given leaves, as BinData's constructor does
    # field by field; any other call shape, or an unknown key, is BinData's.
    module KeywordNew
      def new(*args, **attrs)
        if args.empty? && !attrs.empty?
          template, slots = (@keyword_template ||= keyword_template)
          wire = Emf::Emr::Binary::WireCopy.build(template, slots, attrs)
          return wire if wire
        end
        super
      end

      private

      def keyword_template
        sample = allocate_sample
        [sample, Emf::Emr::Binary::WireCopy.slots(sample)].freeze
      end

      def allocate_sample
        sample = method(:new).super_method.call
        sample.field_names.each { |name| sample.public_send(name) }
        sample
      end
    end

    # Bindata primitives shared by all three formats (WMF, EMF, EMF+).
    # Each record type is declared once and used as a `type:` argument in
    # larger records. See TODO.impl/03-binary-primitives.md.
    module Types
      class PointL < BinData::Record
        endian :little
        int32 :x
        int32 :y
      end

      class PointS < BinData::Record
        endian :little
        int16 :x
        int16 :y
      end

      class PointD < BinData::Record
        endian :little
        double :x
        double :y
      end

      class SizeL < BinData::Record
        endian :little
        int32 :cx
        int32 :cy
      end

      class RectL < BinData::Record
        endian :little
        int32 :left
        int32 :top
        int32 :right
        int32 :bottom
      end

      class RectS < BinData::Record
        endian :little
        int16 :left
        int16 :top
        int16 :right
        int16 :bottom
      end

      class ColorRef < BinData::Record
        endian :little
        uint8 :red
        uint8 :green
        uint8 :blue
        uint8 :reserved
      end

      class XForm < BinData::Record
        endian :little
        float32_le :m11
        float32_le :m12
        float32_le :m21
        float32_le :m22
        float32_le :dx
        float32_le :dy
      end

      class PaletteEntry < BinData::Record
        endian :little
        uint8 :pe_flags
        uint8 :pe_red
        uint8 :pe_green
        uint8 :pe_blue
      end

      class LogPalette < BinData::Record
        endian :little
        uint16 :pal_version
        uint16 :pal_num_entries
        array :pal_pal_entry, type: :palette_entry, initial_length: :pal_num_entries
      end

      class FileTime < BinData::Record
        endian :little
        uint32 :dw_low_date_time
        uint32 :dw_high_date_time
      end

      constants.each { |name| const_get(name).prepend ClassFieldAccessors }

      [PointL, PointS, SizeL, RectL, RectS, ColorRef].each { |type| type.singleton_class.prepend(Emf::Binary::KeywordNew) }
    end
  end
end

# Register the primitives so they can be referenced by name (e.g. `rectl :bounds`)
# inside other BinData records. Bindata resolves types lazily through this registry.
BinData::RegisteredClasses.register("float32_le", Emf::Binary::Float32Le)
BinData::RegisteredClasses.register("point_l", Emf::Binary::Types::PointL)
BinData::RegisteredClasses.register("point_s", Emf::Binary::Types::PointS)
BinData::RegisteredClasses.register("point_d", Emf::Binary::Types::PointD)
BinData::RegisteredClasses.register("size_l", Emf::Binary::Types::SizeL)
BinData::RegisteredClasses.register("rectl", Emf::Binary::Types::RectL)
BinData::RegisteredClasses.register("rect_s", Emf::Binary::Types::RectS)
BinData::RegisteredClasses.register("color_ref", Emf::Binary::Types::ColorRef)
BinData::RegisteredClasses.register("x_form", Emf::Binary::Types::XForm)
BinData::RegisteredClasses.register("palette_entry", Emf::Binary::Types::PaletteEntry)
BinData::RegisteredClasses.register("log_palette", Emf::Binary::Types::LogPalette)
BinData::RegisteredClasses.register("file_time", Emf::Binary::Types::FileTime)
