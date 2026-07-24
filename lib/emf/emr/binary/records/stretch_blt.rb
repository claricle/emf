# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class StretchBlt < Emf::Emr::Binary::WithBounds
          rest :body
        end
      end
    end
  end
end
