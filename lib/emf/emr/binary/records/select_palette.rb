# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SelectPalette < Emf::Emr::Binary::Record
          uint32 :ih_pal
        end
      end
    end
  end
end
