# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class SaveDc < StateRecord
          WIRE_FIELDS = [].freeze
          WIRE_TYPES = [].freeze
          WIRE_FORMAT = ""
          PAYLOAD_BYTES = 0

          def initialize(offset: nil, suffix: "".b, type_id: 0x001E)
            super
          end
        end

        class RestoreDc < StateRecord
          WIRE_FIELDS = %i[saved_dc].freeze
          WIRE_TYPES = %i[int16].freeze
          WIRE_FORMAT = "s<"
          PAYLOAD_BYTES = 2

          def initialize(saved_dc:, offset: nil, suffix: "".b, type_id: 0x0127)
            super(type_id: type_id, offset: offset, suffix: suffix)
            @saved_dc = saved_dc
          end

          attr_accessor :saved_dc
        end

        # Reserved record: every body byte belongs to the preserved suffix.
        class SetRelAbs < StateRecord
          WIRE_FIELDS = [].freeze
          WIRE_TYPES = [].freeze
          WIRE_FORMAT = ""
          PAYLOAD_BYTES = 0

          def initialize(offset: nil, suffix: "".b, type_id: 0x0105)
            super
          end
        end

        # Escape data stays inert, including recognized driver subfunctions.
        class Escape < Record
          def initialize(escape_function:, data:, padding: nil, offset: nil, suffix: "".b, type_id: 0x0626)
            super(type_id: type_id, offset: offset)
            @escape_function = escape_function
            @data = data
            @padding = padding
            @suffix = suffix
          end

          attr_accessor :escape_function, :data, :padding, :suffix
        end
      end
    end
  end
end
