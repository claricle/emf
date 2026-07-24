# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetArcDirection < Emf::Emr::Binary::Record
          uint32 :arc_direction
        end
      end
    end
  end
end
