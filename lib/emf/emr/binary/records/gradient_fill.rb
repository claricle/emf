# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/variable_buffers"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class GradientFill < Emf::Emr::Binary::WithBounds
          include Emf::Emr::Binary::VariableBuffers

          fixed_layout 36
          variable_buffer :vertex_bytes, offset: 36, length: -> { n_ver * 16 }
          variable_buffer :mesh_bytes, offset: -> { 36 + (n_ver * 16) }, length: -> { n_tri * (ul_mode == 2 ? 12 : 8) }

          uint32 :n_ver
          uint32 :n_tri
          uint32 :ul_mode
          rest :body
        end
      end
    end
  end
end
