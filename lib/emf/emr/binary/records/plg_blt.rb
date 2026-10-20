# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/dib_header"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: leading fields per MS-EMF, body captures remaining bytes.
        # The fixed part is 140 bytes including the EMR header; the bitmap
        # pointers are read from body without declaring fields.
        class PlgBlt < Emf::Emr::Binary::WithBounds
          rest :body

          # Read-only accessors computed from body on each call; body starts at
          # record offset 24, so a record offset maps to (offset - 24) in body.
          def off_bmi_src
            pointers(72)[0]
          end

          def cb_bmi_src
            pointers(72)[1]
          end

          def off_bits_src
            pointers(72)[2]
          end

          def cb_bits_src
            pointers(72)[3]
          end

          def off_bmi_mask
            pointers(100)[0]
          end

          def cb_bmi_mask
            pointers(100)[1]
          end

          def off_bits_mask
            pointers(100)[2]
          end

          def cb_bits_mask
            pointers(100)[3]
          end

          def dib_header_view
            DibHeader.view(off_bmi_src, cb_bmi_src, 140, after_fixed,
                           bits_offset: off_bits_src, bits_size: cb_bits_src)
          end

          def mask_dib_header_view
            DibHeader.view(off_bmi_mask, cb_bmi_mask, 140, after_fixed,
                           bits_offset: off_bits_mask, bits_size: cb_bits_mask)
          end

          private

          def after_fixed
            body.to_s.byteslice(116..).to_s
          end

          def pointers(offset)
            body.to_s.byteslice(offset, 16).to_s.unpack("V4").map(&:to_i)
          end
        end
      end
    end
  end
end
