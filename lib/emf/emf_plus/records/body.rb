# frozen_string_literal: true

require "bindata"
require "emf/binary/class_field_accessors"

module Emf
  module EmfPlus
    module Records
      # Base of every BinData structure declared under Records. Its fields are
      # always class-level, so the accessors are defined once per class.
      class Body < BinData::Record
        prepend Emf::Binary::ClassFieldAccessors
      end
    end
  end
end
