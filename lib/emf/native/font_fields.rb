# frozen_string_literal: true

require "emf/emr/binary/font"

module Emf
  module Native
    # Converts family 90 semantic fields directly into editable font objects.
    class FontFields
      LOG_FIELDS = %i[height width escapement orientation weight italic underline strike_out char_set
                      out_precision clip_precision quality pitch_and_family].freeze
      PANOSE_FIELDS = %i[family_type serif_style weight proportion contrast stroke_variation arm_style
                         letterform midline x_height].freeze

      def initialize(payload, raw)
        @payload = payload
        @raw = raw
        @position = 0
      end

      def call
        handle, kind, encoded_size = take(16).unpack("V2Q<")
        font = case kind
               when 0 then Emr::Binary::LogFont.new(log_font)
               when 1 then panose
               when 2 then extended
               else raise FormatError, "invalid native font variant"
               end
        validate_length(kind, encoded_size)
        wire = Emr::Binary::Records::CreateFontIndirectW.new(i_type: 82, n_size: @raw.bytesize, ih_object: handle)
        wire.body.font = font
        wire
      end

      private

      def take(length)
        raise FormatError, "invalid native font payload length" if length > @payload.bytesize - @position

        value = @payload.byteslice(@position, length)
        @position += length
        value
      end

      def log_font
        LOG_FIELDS.zip(take(28).unpack("l<5C8")).to_h.merge(facename: take(64).unpack("v32"))
      end

      def names
        { log_font: log_font, fullname: take(128).unpack("v64"), style: take(64).unpack("v32") }
      end

      def panose
        fields = names.merge(%i[version style_size match reserved].zip(take(16).unpack("V4")).to_h)
        fields.merge!(vendor_id: take(4).bytes, culture: take(4).unpack1("V"),
                      panose: PANOSE_FIELDS.zip(take(10).bytes).to_h, padding: take(2).bytes)
        Emr::Binary::LogFontPanose.new(fields)
      end

      def extended
        fields = names.merge(script: take(64).unpack("v32"))
        signature, count = take(8).unpack("V2")
        raise FormatError, "invalid native font design vector" unless signature == 0x08007664 && count <= 16

        fields[:design_vector] = { signature: signature, num_axes: count, axis_values: take(count * 4).unpack("l<*") }
        fields[:trailing] = @raw.byteslice((12 + @position - 16)..) || "".b
        Emr::Binary::LogFontExDv.new(fields)
      end

      def validate_length(kind, encoded_size)
        valid = valid_size?(kind, encoded_size)
        raise FormatError, "invalid native font payload length" unless valid && @position == @payload.bytesize
        return unless kind == 1

        omitted = @payload.byteslice((16 + encoded_size)..)
        raise FormatError, "invalid native partial font fields" unless omitted.bytes.all?(&:zero?)
      end

      def valid_size?(kind, encoded_size)
        case kind
        when 0 then encoded_size == 92 && @raw.bytesize == 104
        when 1 then (93..320).cover?(encoded_size) && @raw.bytesize == encoded_size + 12
        when 2 then encoded_size == @position - 16 && @raw.bytesize >= encoded_size + 12
        end
      end
    end
  end
end
