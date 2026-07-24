# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetViewportExtEx < Emf::Emr::Binary::Record
          size_l :extent
        end
      end
    end
  end
end
