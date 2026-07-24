# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetRop2 < Emf::Emr::Binary::Record
          uint32 :rop2
        end
      end
    end
  end
end
