# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Stub: preserves full body bytes. Full layout lands with TODO 10.
        class SetTextJustification < Emf::Emr::Binary::Record
          rest :body
        end
      end
    end
  end
end
