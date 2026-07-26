# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetBkMode < Emf::Emr::Binary::Record
          uint32 :bk_mode
        end
      end
    end
  end
end
