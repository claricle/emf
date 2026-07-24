# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetWorldTransform < Emf::Emr::Binary::Record
          x_form :xform
        end
      end
    end
  end
end
