# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/dib_header"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMRCREATEMONOBRUSH (MS-EMF 2.3.7.5).
        # Layout: emr, ihBrush, iUsage, offBmi, cbBmi, offBits, cbBits,
        #         then trailing BMI/bitmap data.
        class CreateMonoBrush < Emf::Emr::Binary::Record
          uint32 :ih_brush
          uint32 :i_usage
          uint32 :off_bmi
          uint32 :cb_bmi
          uint32 :off_bits
          uint32 :cb_bits
          rest :body

          # Read-only; computed from the current fields on each call.
          def dib_header_view
            DibHeader.view(off_bmi, cb_bmi, 32, body)
          end
        end
      end
    end
  end
end
