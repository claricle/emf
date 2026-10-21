# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/dib_header"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: leading fields per MS-EMF, body captures remaining bytes.
        # The fixed part is 108 bytes including the EMR header; the bitmap
        # pointers are read from body without declaring fields.
        class AlphaBlend < Emf::Emr::Binary::WithBounds
          rest :body

          # Read-only accessors computed from body on each call; body starts at
          # record offset 24, so a record offset maps to (offset - 24) in body.
          def off_bmi_src
            pointers(60)[0]
          end

          def cb_bmi_src
            pointers(60)[1]
          end

          def off_bits_src
            pointers(60)[2]
          end

          def cb_bits_src
            pointers(60)[3]
          end

          def dib_header_view
            DibHeader.view(off_bmi_src, cb_bmi_src, 108, after_fixed,
                           bits_offset: off_bits_src, bits_size: cb_bits_src)
          end

          private

          def after_fixed
            body.to_s.byteslice(84..).to_s
          end

          def pointers(offset)
            body.to_s.byteslice(offset, 16).to_s.unpack("V4").map(&:to_i)
          end
        end
      end
    end
  end
end
