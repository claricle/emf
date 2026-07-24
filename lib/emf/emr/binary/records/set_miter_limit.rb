# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetMiterLimit < Emf::Emr::Binary::Record
          float :miter_limit
        end
      end
    end
  end
end
