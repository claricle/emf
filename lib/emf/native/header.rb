# frozen_string_literal: true

module Emf
  module Native
    class Header
      def signed(values)
        values.pack("V*").unpack("l<*")
      end

      def rect(values)
        Model::Geometry::Rect.new(**%i[left top right bottom].zip(signed(values)).to_h)
      end

      def size(values)
        Model::Geometry::Size.new(**%i[cx cy].zip(signed(values)).to_h)
      end

      def call(fields, raw_header)
        extension = if fields[22].anybits?(2)
                      108
                    else
                      (fields[22].anybits?(1) ? 100 : 88)
                    end
        Model::Emr::Header.new(
          n_size: fields[0], bounds: rect(fields[1, 4]), frame: rect(fields[5, 4]),
          signature: fields[9], version: fields[10], n_bytes: fields[11], n_records: fields[12],
          n_handles: fields[13], s_reserved: fields[14], n_description: fields[15], off_description: fields[16],
          n_pal_entries: fields[17], device_pixels: size(fields[18, 2]), device_mm: size(fields[20, 2]),
          cb_pixel_format: fields[23], off_pixel_format: fields[24], b_open_gl: fields[25],
          szl_micrometers: size(fields[26, 2]), trailing: raw_header.byteslice(extension..) || "".b
        )
      end
    end
  end
end
