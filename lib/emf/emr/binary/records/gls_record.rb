# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_GLSRECORD (MS-EMF 2.3.5.24).
        class GlsRecord < Emf::Emr::Binary::Record
          rest :body

          def cb_data
            gls_body(4).byteslice(0, 4).unpack1("V")
          end

          def data_bytes
            read_gls_data(4)
          end

          def data_bytes=(value)
            write_gls_data(4, value)
          end

          private

          def gls_body(prefix_length)
            bytes = body.to_s
            raise ArgumentError, "truncated GLS record prefix" if bytes.bytesize < prefix_length

            bytes
          end

          def read_gls_data(prefix_length)
            bytes = gls_body(prefix_length)
            length = bytes.byteslice(0, 4).unpack1("V")
            raise ArgumentError, "truncated GLS record data" if prefix_length + length > bytes.bytesize

            bytes.byteslice(prefix_length, length).b
          end

          def write_gls_data(prefix_length, value)
            read_gls_data(prefix_length)
            length = cb_data
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "GLS record data must be a String of #{length} bytes"
            end

            bytes = body.to_s.b
            bytes[prefix_length, length] = value.b
            self.body = bytes
          end
        end
      end
    end
  end
end
