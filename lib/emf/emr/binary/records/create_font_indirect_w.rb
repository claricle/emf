# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: ihObject + body bytes; full LOGFONT_PANOSE layout in TODO 10.
        class CreateFontIndirectW < Emf::Emr::Binary::Record
          uint32 :ih_object
          rest :body
        end
      end
    end
  end
end
