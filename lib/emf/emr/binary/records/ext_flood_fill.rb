# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/state_record_body"

module Emf
  module Emr
    module Binary
      module Records
        class ExtFloodFill < Emf::Emr::Binary::Record
          include StateRecordBody

          BODY_SIZE = 16

          point_l :start
          color_ref :color
          uint32 :flood_fill_mode
          rest :trailing
        end
      end
    end
  end
end
