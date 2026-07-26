# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_SETTEXTCOLOR: iType, nSize, then a COLORREF.
        class SetTextColor < Emf::Emr::Binary::Record
          color_ref :color
        end
      end
    end
  end
end
