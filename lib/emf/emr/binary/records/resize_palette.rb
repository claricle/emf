# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class ResizePalette < Emf::Emr::Binary::Record
          uint32 :ih_pal
          uint32 :entry_count
          rest :trailing

          def body
            to_binary_s.byteslice(8..)
          end
        end
      end
    end
  end
end
