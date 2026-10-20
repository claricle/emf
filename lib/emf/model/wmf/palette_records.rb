# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        PaletteEntry = Struct.new(:red, :green, :blue, :flags, keyword_init: true)

        class PaletteRecord < Record
          def initialize(type_id:, start:, entries:, offset: nil, suffix: "".b)
            super(type_id: type_id, offset: offset)
            @start = start
            @entries = entries
            @suffix = suffix
          end

          attr_accessor :start, :entries, :suffix
        end

        class CreatePalette < PaletteRecord
          def initialize(start:, entries:, offset: nil, suffix: "".b, type_id: 0x00F7)
            super
          end
        end

        class SetPalEntries < PaletteRecord
          def initialize(start:, entries:, offset: nil, suffix: "".b, type_id: 0x0037)
            super
          end
        end

        class AnimatePalette < PaletteRecord
          def initialize(start:, entries:, offset: nil, suffix: "".b, type_id: 0x0436)
            super
          end
        end

        class SelectPalette < ObjectReference
          def initialize(object_index:, offset: nil, suffix: "".b, type_id: 0x0234)
            super(type_id: type_id, offset: offset, object_index: object_index)
            @suffix = suffix
          end

          attr_accessor :suffix
        end

        class ResizePalette < Record
          def initialize(entry_count:, offset: nil, suffix: "".b, type_id: 0x0139)
            super(type_id: type_id, offset: offset)
            @entry_count = entry_count
            @suffix = suffix
          end

          attr_accessor :entry_count, :suffix
        end

        class RealizePalette < Record
          def initialize(offset: nil, suffix: "".b, type_id: 0x0035)
            super(type_id: type_id, offset: offset)
            @suffix = suffix
          end

          attr_accessor :suffix
        end
      end
    end
  end
end
