# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      autoload :Header, "emf/emr/binary/header"
      autoload :Record, "emf/emr/binary/record"
      autoload :WithBounds, "emf/emr/binary/with_bounds"
      autoload :TypeCodes, "emf/emr/binary/type_codes"
      autoload :FastFill, "emf/emr/binary/fast_fill"
      autoload :Records, "emf/emr/binary/records"
    end
  end
end
