# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class CreatePalette < Emf::Emr::Binary::Record
          uint32 :ih_pal
          rest :body
        end
      end
    end
  end
end
