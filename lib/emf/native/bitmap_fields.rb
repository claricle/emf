# frozen_string_literal: true

module Emf
  module Native
    module BitmapFields
      # family => [EMR type, fixed size including EMR header, source pointer offset, mask pointer offset]
      LAYOUTS = {
        94 => [76, 100, 84, nil], 95 => [77, 108, 84, nil], 96 => [78, 128, 84, 112],
        97 => [79, 140, 96, 124], 98 => [80, 76, 48, nil], 99 => [81, 80, 48, nil],
        100 => [93, 32, 16, nil], 101 => [94, 32, 16, nil],
        102 => [114, 108, 84, nil], 103 => [116, 108, 84, nil]
      }.freeze
      POINTERS = %i[off_bmi_src cb_bmi_src off_bits_src cb_bits_src].freeze
      BLT = %i[x_dest y_dest cx_dest cy_dest dw_rop x_src y_src].freeze
      DIB = %i[x_dest y_dest x_src y_src cx_src cy_src off_bmi_src cb_bmi_src off_bits_src cb_bits_src i_usage_src dw_rop cx_dest
               cy_dest].freeze
      BRUSH = %i[ih_brush i_usage off_bmi cb_bmi off_bits cb_bits].freeze

      def self.call(payload, family, raw)
        return GradientFields.call(payload, raw) if family == 93

        type, fixed, source, mask = LAYOUTS.fetch(family)
        validate(payload, raw, fixed, source, mask)
        suffix = raw.byteslice((payload.bytesize + 8)..)
        fields = if [93, 94].include?(type)
                   BRUSH.zip(payload.unpack("V6")).to_h.merge(body: payload.byteslice(24..) + suffix)
                 else
                   bounds = { rcl_bounds: %i[left top right bottom].zip(payload.unpack("l<4")).to_h }
                   bounds.merge(transfer(payload, type, fixed, suffix))
                 end
        [Emr::Binary::Records.lookup(type), fields]
      end

      def self.transfer(payload, type, fixed, suffix)
        case type
        when 76, 77
          fields = BLT.zip(payload.byteslice(16, 28).unpack("l<4Vl<2")).to_h
          fields[:xform_usage_etc] = payload.byteslice(44, 32).sub(/\x00+\z/n, "")
          fields.merge!(POINTERS.zip(payload.byteslice(76, 16).unpack("V4")).to_h)
          fields.merge!(%i[cx_src cy_src].zip(payload.byteslice(92, 8).unpack("l<2")).to_h) if type == 77
          fields.merge(body: payload.byteslice((fixed - 8)..) + suffix)
        when 81
          DIB.zip(payload.byteslice(16, 56).unpack("l<6V6l<2")).to_h.merge(trailing: payload.byteslice(72..) + suffix)
        else
          { body: payload.byteslice(16..) + suffix }
        end
      end

      def self.validate(payload, raw, fixed, source, mask)
        raise FormatError, "invalid native bitmap payload length" if payload.bytesize < fixed - 8 || raw.bytesize < payload.bytesize + 8

        spans = [source, mask].compact.flat_map do |offset|
          payload.byteslice(offset - 8, 16).unpack("V4").each_slice(2).reject { |start, length| start.zero? && length.zero? }
        end
        cursor = fixed
        spans.sort.each do |start, length|
          raise FormatError, "invalid native bitmap buffer span" if start < cursor || length > payload.bytesize + 8 - start

          cursor = start + length
        end
        raise FormatError, "invalid native bitmap trailing length" unless cursor == payload.bytesize + 8
      end
    end
  end
end
