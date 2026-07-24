# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_PIXELFORMAT: header + body. Stub preserves bytes verbatim.
        class PixelFormat < Emf::Emr::Binary::Record
          rest :body
        end
      end
    end
  end
end
