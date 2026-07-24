# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class IntersectClipRect < Emf::Emr::Binary::Record
          rectl :rcl_clip
        end
      end
    end
  end
end
