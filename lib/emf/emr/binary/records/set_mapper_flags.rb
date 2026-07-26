# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetMapperFlags < Emf::Emr::Binary::Record
          uint32 :flags
        end
      end
    end
  end
end
