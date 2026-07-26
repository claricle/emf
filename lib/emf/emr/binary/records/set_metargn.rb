# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_SETMETARGN: no payload, just the header.
        class SetMetArgn < Emf::Emr::Binary::Record
        end
      end
    end
  end
end
