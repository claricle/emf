# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/lazy_utf16_array"

module Emf
  module Emr
    module Binary
      # Fixed UTF-16 fields retain code units, including units after a terminator.
      class LogFont < BinData::Record
        endian :little
        int32 :height
        int32 :width
        int32 :escapement
        int32 :orientation
        int32 :weight
        uint8 :italic
        uint8 :underline
        uint8 :strike_out
        uint8 :char_set
        uint8 :out_precision
        uint8 :clip_precision
        uint8 :quality
        uint8 :pitch_and_family
        lazy_utf16_array :facename, initial_length: 32
      end

      class Panose < BinData::Record
        uint8 :family_type
        uint8 :serif_style
        uint8 :weight
        uint8 :proportion
        uint8 :contrast
        uint8 :stroke_variation
        uint8 :arm_style
        uint8 :letterform
        uint8 :midline
        uint8 :x_height
      end

      class LogFontPanose < BinData::Record
        endian :little
        log_font :log_font
        lazy_utf16_array :fullname, initial_length: 64
        lazy_utf16_array :style, initial_length: 32
        uint32 :version
        uint32 :style_size
        uint32 :match
        uint32 :reserved
        array :vendor_id, type: :uint8, initial_length: 4
        uint32 :culture
        panose :panose
        array :padding, type: :uint8, initial_length: 2
      end

      class DesignVector < BinData::Record
        endian :little
        uint32 :signature
        uint32 :num_axes
        array :axis_values, type: :int32, initial_length: :num_axes
      end

      class LogFontExDv < BinData::Record
        endian :little
        log_font :log_font
        lazy_utf16_array :fullname, initial_length: 64
        lazy_utf16_array :style, initial_length: 32
        lazy_utf16_array :script, initial_length: 32
        design_vector :design_vector
        rest :trailing
      end

      # The byte snapshot preserves the existing body API; font exposes the fields.
      class FontBody < BinData::BasePrimitive
        mandatory_parameter :byte_length

        attr_accessor :font

        def assign(value)
          bytes = value.respond_to?(:snapshot) ? value.snapshot : value
          @font = parse_font(bytes)
          super(bytes)
        end

        def snapshot
          @font ? value_to_binary_string(nil) : super
        end

        private

        def read_and_return_value(io)
          length = eval_parameter(:byte_length)
          raise BinData::ValidityError, "font body is shorter than LOGFONT" if length < 92

          bytes = io.readbytes(length)
          @font = parse_font(bytes)
          bytes
        rescue IOError => e
          raise BinData::ValidityError, e.message
        end

        def parse_font(bytes)
          size = bytes.bytesize
          raise BinData::ValidityError, "font body is shorter than LOGFONT" if size < 92

          return LogFont.read(bytes) if size == 92
          return LogFontPanose.read(bytes.ljust(320, "\0")) if size <= 320

          validate_exdv(bytes)
          LogFontExDv.read(bytes)
        end

        def validate_exdv(bytes)
          raise BinData::ValidityError, "truncated LOGFONTEXDV" if bytes.bytesize < 356

          signature, axes = bytes.byteslice(348, 8).unpack("V2")
          raise BinData::ValidityError, "invalid design vector signature" unless signature == 0x08007664
          raise BinData::ValidityError, "invalid design vector axis count" if axes > 16
          raise BinData::ValidityError, "truncated design vector" if bytes.bytesize < 356 + (axes * 4)
        end

        def value_to_binary_string(value)
          return value unless @font

          bytes = @font.to_binary_s
          if @font.is_a?(LogFontExDv)
            validate_exdv(bytes)
            unless @font.design_vector.axis_values.length == @font.design_vector.num_axes
              raise BinData::ValidityError, "design vector axis count does not match values"
            end
          end
          length = eval_parameter(:byte_length)
          if @font.is_a?(LogFontPanose) && length.between?(93, 319)
            raise BinData::ValidityError, "font edit exceeds partial Panose body" unless bytes.byteslice(length..).bytes.all?(&:zero?)

            return bytes.byteslice(0, length)
          end
          raise BinData::ValidityError, "font body does not match record size" unless bytes.bytesize == length

          bytes
        end

        def sensible_default
          "".b
        end
      end
    end
  end
end
