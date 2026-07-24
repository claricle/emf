# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class ModifyWorldTransform < Emf::Emr::Binary::Record
          x_form :xform
          uint32 :modify_mode
        end
      end
    end
  end
end
