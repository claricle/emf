# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/region_data"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTSELECTCLIPRGN: emr + cbRgnData + dwMode + RgnData[cbRgnData].
        class ExtSelectClipRgn < Emf::Emr::Binary::Record
          uint32 :cb_rgn_data
          uint32 :dw_mode
          region_data :rgn_data, byte_length: :cb_rgn_data, onlyif: -> { cb_rgn_data.positive? }
          rest :body
        end
      end
    end
  end
end
