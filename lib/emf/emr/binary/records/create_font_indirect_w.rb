# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/font"

module Emf
  module Emr
    module Binary
      module Records
        class CreateFontIndirectW < Emf::Emr::Binary::Record
          uint32 :ih_object
          font_body :body, byte_length: -> { n_size - 12 }

          def elw
            body.font
          end
        end
      end
    end
  end
end
