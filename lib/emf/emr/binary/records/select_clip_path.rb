# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_SELECTCLIPPATH per MS-EMF 2.3.2.5.
        # Some EMF writers omit rclBounds (Size=12 instead of 28).
        # We declare only the mandatory fields; rclBounds is optional.
        class SelectClipPath < Emf::Emr::Binary::Record
          uint32 :region_mode
          rest :trailing
        end
      end
    end
  end
end
