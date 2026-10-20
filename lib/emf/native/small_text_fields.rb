# frozen_string_literal: true

module Emf
  module Native
    # Hydrates the fixed EMRSMALLTEXTOUT prefix and leaves option-dependent
    # text bytes opaque for the Ruby visitor.
    module SmallTextFields
      FIXED_SIZE = 36

      def self.call(raw)
        return [Emr::Binary::Records::Raw, { payload: raw.byteslice(8..) }] if raw.bytesize < FIXED_SIZE

        [Emr::Binary::Records::SmallTextOut,
         {
           x_dest: raw.byteslice(8, 4).unpack1("l<"),
           y_dest: raw.byteslice(12, 4).unpack1("l<"),
           c_chars: raw.byteslice(16, 4).unpack1("V"),
           fu_options: raw.byteslice(20, 4).unpack1("V"),
           i_graphics_mode: raw.byteslice(24, 4).unpack1("V"),
           ex_scale: raw.byteslice(28, 4).unpack1("e"),
           ey_scale: raw.byteslice(32, 4).unpack1("e"),
           body: raw.byteslice(FIXED_SIZE..)
         }]
      end
    end
  end
end
