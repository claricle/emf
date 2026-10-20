# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMRSMALLTEXTOUT (MS-EMF 2.3.5.37).
        # Layout: emr, Dest, cChars, fuOptions, iGraphicsMode, exScale (float),
        # eyScale (float), [optional RECTL], TextString (1 or 2 bytes per char).
        # Option-dependent bounds and text are exposed as raw bytes while the
        # body retains the original wire layout and any trailing bytes.
        class SmallTextOut < Emf::Emr::Binary::Record
          int32 :x_dest
          int32 :y_dest
          uint32 :c_chars
          uint32 :fu_options
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          rest :body

          def bounds
            return nil if no_rectangle?

            available_body(16).byteslice(0, 16).b
          end

          def bounds=(value)
            raise ArgumentError, "small text output has no bounds rectangle" if no_rectangle?

            write_body_bytes(0, 16, value)
          end

          def text_bytes
            offset, length = text_region
            available_body(offset + length).byteslice(offset, length).b
          end

          def text_bytes=(value)
            offset, length = text_region
            write_body_bytes(offset, length, value)
          end

          private

          def no_rectangle?
            fu_options.to_i.anybits?(0x100)
          end

          def text_region
            width = fu_options.to_i.nobits?(0x200) ? 2 : 1
            [no_rectangle? ? 0 : 16, c_chars.to_i * width]
          end

          def available_body(required_length)
            bytes = body.to_s
            raise ArgumentError, "truncated small text output body" if bytes.bytesize < required_length

            bytes
          end

          def write_body_bytes(offset, length, value)
            bytes = available_body(offset + length)
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "small text output value must be a String of #{length} bytes"
            end

            replacement = bytes.b
            replacement[offset, length] = value.b
            self.body = replacement
          end
        end
      end
    end
  end
end
