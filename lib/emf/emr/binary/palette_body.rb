# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      class PaletteBody < String
        def initialize(record, bytes)
          @record = record
          super(bytes)
        end

        def assign(bytes)
          @record.body = bytes
          replace(@record.body)
        end
      end
    end
  end
end
