# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      module StateRecordBody
        class Body < String
          def initialize(record, bytes)
            @record = record
            super(bytes)
          end

          def assign(bytes)
            @record.body = bytes
            replace(@record.body)
          end
        end

        def body
          Body.new(self, to_binary_s.byteslice(8..))
        end

        def body=(value)
          bytes = value.to_s
          raise ArgumentError, "invalid state record body length" if bytes.bytesize < self.class::BODY_SIZE

          replacement = self.class.read(to_binary_s.byteslice(0, 8) + bytes)
          assign(replacement.snapshot)
        end
      end
    end
  end
end
