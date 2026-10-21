# frozen_string_literal: true

module Emf
  module Native
    module BitmapFields
      # family => [EMR type, fixed size including EMR header]
      LAYOUTS = {
        94 => [76, 100], 95 => [77, 108], 96 => [78, 128],
        97 => [79, 140], 98 => [80, 76], 99 => [81, 80],
        100 => [93, 32], 101 => [94, 32],
        102 => [114, 108], 103 => [116, 108]
      }.freeze
      POINTERS = %i[off_bmi_src cb_bmi_src off_bits_src cb_bits_src].freeze
      BLT = %i[x_dest y_dest cx_dest cy_dest dw_rop x_src y_src].freeze
      DIB = %i[x_dest y_dest x_src y_src cx_src cy_src off_bmi_src cb_bmi_src off_bits_src cb_bits_src i_usage_src dw_rop cx_dest
               cy_dest].freeze
      BRUSH = %i[ih_brush i_usage off_bmi cb_bmi off_bits cb_bits].freeze

      def self.call(payload, family, raw)
        return GradientFields.call(payload, raw) if family == 93

        type, fixed = LAYOUTS.fetch(family)
        validate(payload, raw, fixed)
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

      # The snapshot payload always starts with the fixed prefix; descriptors are
      # not checked against the record, because Ruby keeps the rest as opaque body.
      def self.validate(payload, raw, fixed)
        return unless payload.bytesize < fixed - 8 || raw.bytesize < payload.bytesize + 8

        raise FormatError, "invalid native bitmap payload length"
      end
    end
  end
end
