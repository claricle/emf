# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      module Records
        class CreateFontIndirect < ObjectRecord
          SIGNED_FIELDS = %i[height width escapement orientation weight].freeze
          BYTE_FIELDS = %i[italic underline strike_out char_set out_precision clip_precision quality pitch_and_family].freeze
          WIRE_FIELDS = (SIGNED_FIELDS + BYTE_FIELDS + [:face_name]).freeze
          WIRE_FORMAT = "s<5C8a32"
          PAYLOAD_BYTES = 50

          def initialize(height:, width:, escapement:, orientation:, weight:, italic:, underline:, strike_out:,
                         char_set:, out_precision:, clip_precision:, quality:, pitch_and_family:, face_name:,
                         offset: nil, type_id: 0x02FB, suffix: "")
            super(type_id: type_id, offset: offset)
            @height = height
            @width = width
            @escapement = escapement
            @orientation = orientation
            @weight = weight
            @italic = italic
            @underline = underline
            @strike_out = strike_out
            @char_set = char_set
            @out_precision = out_precision
            @clip_precision = clip_precision
            @quality = quality
            @pitch_and_family = pitch_and_family
            @face_name = face_name
            @suffix = suffix
          end

          attr_accessor(*WIRE_FIELDS, :suffix)
        end
      end
    end
  end
end
