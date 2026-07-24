# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class CreateMonoBrush < Emf::Emr::Binary::Record
          uint32 :ih_object
          rest :body
        end
      end
    end
  end
end
