# frozen_string_literal: true

require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/graphics_version"
require "emf/emf_plus/records/primitives/point_f"
require "emf/emf_plus/records/primitives/path"

module Emf
  module EmfPlus
    module Objects
      # EmfPlusCustomLineCap (2.2.1.2): Version, Type, then the default
      # (2.2.2.13) or adjustable arrow (2.2.2.12) data the Type selects.
      class CustomLineCap < Typed
        DEFAULT = 0
        ADJUSTABLE_ARROW = 1

        DATA_FILL_PATH = 0x01
        DATA_LINE_PATH = 0x02

        class CustomLineCapHeader < Records::Body
          endian :little
          graphics_version :version
          uint32 :cap_type
        end

        # EmfPlusCustomLineCapData (2.2.2.13) without OptionalData.
        class CustomLineCapDefaultData < Records::Body
          endian :little
          uint32 :custom_line_cap_data_flags
          uint32 :base_cap
          float32_le :base_inset
          uint32 :stroke_start_cap
          uint32 :stroke_end_cap
          uint32 :stroke_join
          float32_le :stroke_miter_limit
          float32_le :width_scale
          point_f :fill_hot_spot
          point_f :stroke_hot_spot
        end

        # EmfPlusCustomLineCapArrowData (2.2.2.12).
        class CustomLineCapArrowData < Records::Body
          endian :little
          float32_le :width
          float32_le :height
          float32_le :middle_inset
          uint32 :fill_state
          uint32 :line_start_cap
          uint32 :line_end_cap
          uint32 :line_join
          float32_le :line_miter_limit
          float32_le :width_scale
          point_f :fill_hot_spot
          point_f :line_hot_spot
        end

        P = Records::Primitives
        private_constant :P

        # Walks the data once, reading the optional paths the flags select.
        class Reader
          def initialize(data)
            @cursor = Parts::Cursor.new(data)
          end

          def read
            @cursor.take(:header, CustomLineCapHeader)
            read_cap_data(@cursor.parts.fetch(:header).cap_type)
            Parts::Body.new(@cursor.parts)
          end

          private

          def read_cap_data(cap_type)
            case cap_type
            when DEFAULT then read_default
            when ADJUSTABLE_ARROW then @cursor.take(:data, CustomLineCapArrowData)
            else @cursor.take_rest(:unknown_data)
            end
          end

          def read_default
            @cursor.take(:data, CustomLineCapDefaultData)
            flags = @cursor.parts.fetch(:data).custom_line_cap_data_flags
            @cursor.take_sized(:fill_path) { |bytes| P::Path.new.read(bytes) } if flags.anybits?(DATA_FILL_PATH)
            @cursor.take_sized(:line_path) { |bytes| P::Path.new.read(bytes) } if flags.anybits?(DATA_LINE_PATH)
          end
        end

        def cap_type = body.parts.fetch(:header).cap_type
        def data = body.parts[:data]
        def fill_path = body.parts[:fill_path]&.inner
        def line_path = body.parts[:line_path]&.inner
        def unknown_data = body.parts[:unknown_data]

        private

        def read_body(data, logical)
          Reader.new(data).read
        rescue IOError, BinData::ValidityError, Parts::Malformed => e
          fail_parse(logical, e.message)
        end
      end
    end
  end
end
