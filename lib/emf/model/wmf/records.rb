# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class Record < Emf::Model::Record
          Emf::Model::Visitor.register_visit(:visit_wmf_record, self)

          def initialize(type_id:, offset: nil)
            super()
            @type_id = type_id
            @offset = offset
          end

          attr_reader :type_id, :offset

          def accept(visitor)
            visitor.visit_wmf_record(self)
          end
        end

        class Eof < Record
          def initialize(offset: nil)
            super(type_id: 0, offset: offset)
          end
        end

        class PointRecord < Record
          def initialize(type_id:, x:, y:, offset: nil)
            super(type_id: type_id, offset: offset)
            @x = x
            @y = y
          end

          attr_accessor :x, :y
        end

        class MoveTo < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x0214)
            super
          end
        end

        class LineTo < PointRecord
          def initialize(x:, y:, offset: nil, type_id: 0x0213)
            super
          end
        end

        class UnknownRecord < Record
          def initialize(type_id:, raw_bytes:, offset: nil)
            super(type_id: type_id, offset: offset)
            @raw_bytes = raw_bytes.dup.freeze
          end

          attr_reader :raw_bytes
        end
      end
    end
  end
end
