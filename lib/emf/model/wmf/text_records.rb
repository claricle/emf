# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        TextRectangle = Struct.new(:left, :top, :right, :bottom, keyword_init: true)

        class TextOut < Record
          def initialize(text:, x:, y:, padding: "\x00".b, offset: nil, type_id: 0x0521)
            super(type_id: type_id, offset: offset)
            @text = text
            @x = x
            @y = y
            @padding = padding
          end

          attr_accessor :text, :x, :y, :padding
        end

        class ExtTextOut < TextOut
          def initialize(text:, x:, y:, options: 0, rectangle: nil, dx: nil, padding: "\x00".b, suffix: "".b,
                         offset: nil, type_id: 0x0A32)
            super(text: text, x: x, y: y, padding: padding, offset: offset, type_id: type_id)
            @options = options
            @rectangle = rectangle
            @dx = dx
            @suffix = suffix
          end

          attr_accessor :options, :rectangle, :dx, :suffix
        end
      end
    end
  end
end
