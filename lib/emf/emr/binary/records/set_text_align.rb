# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetTextAlign < Emf::Emr::Binary::Record
          uint32 :text_align_mode
        end
      end
    end
  end
end
