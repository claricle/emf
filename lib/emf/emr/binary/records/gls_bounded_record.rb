# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_GLSBOUNDEDRECORD (MS-EMF 2.3.5.23).
        class GlsBoundedRecord < Emf::Emr::Binary::Record
          rest :body

          def bounds
            gls_body.byteslice(0, 16).b
          end

          def bounds=(value)
            write_gls_bytes(0, 16, value)
          end

          def cb_data
            gls_body.byteslice(16, 4).unpack1("V")
          end

          def data_bytes
            read_gls_data
          end

          def data_bytes=(value)
            write_gls_data(value)
          end

          private

          def gls_body
            bytes = body.to_s
            raise ArgumentError, "truncated bounded GLS record prefix" if bytes.bytesize < 20

            bytes
          end

          def read_gls_data
            bytes = gls_body
            length = bytes.byteslice(16, 4).unpack1("V")
            raise ArgumentError, "truncated bounded GLS record data" if 20 + length > bytes.bytesize

            bytes.byteslice(20, length).b
          end

          def write_gls_data(value)
            read_gls_data
            length = cb_data
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "bounded GLS data must be a String of #{length} bytes"
            end

            bytes = body.to_s.b
            bytes[20, length] = value.b
            self.body = bytes
          end

          def write_gls_bytes(offset, length, value)
            gls_body
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "bounded GLS value must be a String of #{length} bytes"
            end

            bytes = body.to_s.b
            bytes[offset, length] = value.b
            self.body = bytes
          end
        end
      end
    end
  end
end
