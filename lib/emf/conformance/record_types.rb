# frozen_string_literal: true

module Emf
  module Conformance
    # EMF record type codes of MS-EMF 2.1.1 (RecordType enumeration): 1..122
    # except 69, 107 and 117, which the enumeration does not define.
    module RecordTypes
      UNDEFINED = [69, 107, 117].freeze
      DEFINED = ((1..122).to_a - UNDEFINED).freeze
      HEADER = 1
      EOF_RECORD = 14
      COMMENT = 70

      module_function

      def defined?(type) = DEFINED.include?(type)

      def name(type)
        Emf::Emr::Binary::TypeCodes.constants.find { |c| Emf::Emr::Binary::TypeCodes.const_get(c) == type }&.to_s ||
          format("0x%04X", type)
      end
    end
  end
end
