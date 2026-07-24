# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Control record with no payload (just iType and nSize).
        class FillPath < Emf::Emr::Binary::Record
        end
      end
    end
  end
end
