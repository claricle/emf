# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTSELECTCLIPRGN: emr + cbRgnData + dwMode + RgnData[cbRgnData].
        class ExtSelectClipRgn < Emf::Emr::Binary::Record
          uint32 :cb_rgn_data
          uint32 :dw_mode
          rest :rgn_data
        end
      end
    end
  end
end
