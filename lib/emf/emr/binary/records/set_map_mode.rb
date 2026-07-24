# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetMapMode < Emf::Emr::Binary::Record
          uint32 :map_mode
        end
      end
    end
  end
end
