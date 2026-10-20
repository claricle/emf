# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class StateRecord < Record
          def initialize(type_id:, offset: nil, suffix: "")
            super(type_id: type_id, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class SetBkColor < StateRecord
          WIRE_FIELDS = %i[color_ref].freeze
          WIRE_FORMAT = "V"
          WIRE_TYPES = %i[uint32].freeze
          PAYLOAD_BYTES = 4

          def initialize(color_ref:, offset: nil, type_id: 0x0201, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @color_ref = color_ref
          end

          attr_accessor :color_ref
        end

        class SetBkMode < StateRecord
          WIRE_FIELDS = %i[mode].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(mode:, offset: nil, type_id: 0x0102, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class SetMapMode < StateRecord
          WIRE_FIELDS = %i[mode].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(mode:, offset: nil, type_id: 0x0103, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class SetMapperFlags < StateRecord
          WIRE_FIELDS = %i[flags].freeze
          WIRE_FORMAT = "V"
          WIRE_TYPES = %i[uint32].freeze
          PAYLOAD_BYTES = 4

          def initialize(flags:, offset: nil, type_id: 0x0231, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @flags = flags
          end

          attr_accessor :flags
        end

        class SetPolyFillMode < StateRecord
          WIRE_FIELDS = %i[mode].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(mode:, offset: nil, type_id: 0x0106, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class SetRop2 < StateRecord
          WIRE_FIELDS = %i[mode].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(mode:, offset: nil, type_id: 0x0104, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class SetStretchBltMode < StateRecord
          WIRE_FIELDS = %i[mode].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(mode:, offset: nil, type_id: 0x0107, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @mode = mode
          end

          attr_accessor :mode
        end

        class SetTextAlign < StateRecord
          WIRE_FIELDS = %i[alignment].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(alignment:, offset: nil, type_id: 0x012E, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @alignment = alignment
          end

          attr_accessor :alignment
        end

        class SetTextCharExtra < StateRecord
          WIRE_FIELDS = %i[char_extra].freeze
          WIRE_FORMAT = "v"
          WIRE_TYPES = %i[uint16].freeze
          PAYLOAD_BYTES = 2

          def initialize(char_extra:, offset: nil, type_id: 0x0108, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @char_extra = char_extra
          end

          attr_accessor :char_extra
        end

        class SetTextColor < StateRecord
          WIRE_FIELDS = %i[color_ref].freeze
          WIRE_FORMAT = "V"
          WIRE_TYPES = %i[uint32].freeze
          PAYLOAD_BYTES = 4

          def initialize(color_ref:, offset: nil, type_id: 0x0209, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @color_ref = color_ref
          end

          attr_accessor :color_ref
        end

        class SetTextJustification < StateRecord
          WIRE_FIELDS = %i[break_count break_extra].freeze
          WIRE_FORMAT = "vv"
          WIRE_TYPES = %i[uint16 uint16].freeze
          PAYLOAD_BYTES = 4

          def initialize(break_count:, break_extra:, offset: nil, type_id: 0x020A, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @break_count = break_count
            @break_extra = break_extra
          end

          attr_accessor :break_count, :break_extra
        end

        class SetLayout < StateRecord
          WIRE_FIELDS = %i[layout reserved].freeze
          WIRE_FORMAT = "vv"
          WIRE_TYPES = %i[uint16 uint16].freeze
          PAYLOAD_BYTES = 4

          def initialize(layout:, reserved:, offset: nil, type_id: 0x0149, suffix: "")
            super(type_id: type_id, offset: offset, suffix: suffix)
            @layout = layout
            @reserved = reserved
          end

          attr_accessor :layout, :reserved
        end
      end
    end
  end
end
