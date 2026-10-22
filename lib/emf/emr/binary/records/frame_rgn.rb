# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/variable_buffers"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/region_data"

module Emf
  module Emr
    module Binary
      module Records
        class FrameRgn < Emf::Emr::Binary::WithBounds
          include Emf::Emr::Binary::VariableBuffers

          fixed_layout 40
          variable_buffer :region_bytes, offset: 40, length: :cb_rgn_data

          uint32 :cb_rgn_data
          uint32 :ih_brush
          size_l :szl_stroke
          region_data :rgn_data, byte_length: :cb_rgn_data
          rest :body
        end
      end
    end
  end
end
