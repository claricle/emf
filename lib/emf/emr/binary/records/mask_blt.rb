# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/variable_buffers"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/dib_header"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: leading fields per MS-EMF, body captures remaining bytes.
        # The fixed part is 128 bytes including the EMR header; the bitmap
        # pointers are read from body without declaring fields.
        class MaskBlt < Emf::Emr::Binary::WithBounds
          include Emf::Emr::Binary::VariableBuffers

          fixed_layout 128
          variable_buffer :bmi_bytes, offset: :off_bmi_src, length: :cb_bmi_src
          variable_buffer :bits_bytes, offset: :off_bits_src, length: :cb_bits_src
          variable_buffer :mask_bmi_bytes, offset: :off_bmi_mask, length: :cb_bmi_mask
          variable_buffer :mask_bits_bytes, offset: :off_bits_mask, length: :cb_bits_mask

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

          def off_bmi_mask
            pointers(88)[0]
          end

          def cb_bmi_mask
            pointers(88)[1]
          end

          def off_bits_mask
            pointers(88)[2]
          end

          def cb_bits_mask
            pointers(88)[3]
          end

          def dib_header_view
            DibHeader.view(off_bmi_src, cb_bmi_src, 128, after_fixed,
                           bits_offset: off_bits_src, bits_size: cb_bits_src)
          end

          def mask_dib_header_view
            DibHeader.view(off_bmi_mask, cb_bmi_mask, 128, after_fixed,
                           bits_offset: off_bits_mask, bits_size: cb_bits_mask)
          end

          private

          def after_fixed
            body.to_s.byteslice(104..).to_s
          end

          def pointers(offset)
            body.to_s.byteslice(offset, 16).to_s.unpack("V4").map(&:to_i)
          end
        end
      end
    end
  end
end
