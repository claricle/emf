# frozen_string_literal: true

module Emf
  module Model
    module Emr
      # EMF metafile header. Preserves all wire fields verbatim so the
      # serializer can round-trip byte-faithfully.
      class Header
        def initialize(bounds:, frame:, signature:, version:, n_bytes:, n_records:,
                       n_handles:, s_reserved:, n_description:, off_description:,
                       n_pal_entries:, device_pixels:, device_mm:, cb_pixel_format:,
                       off_pixel_format:, b_open_gl:, szl_micrometers:,
                       n_size: 100, trailing: +"", description: nil)
          @bounds = bounds
          @frame = frame
          @signature = signature
          @version = version
          @n_bytes = n_bytes
          @n_records = n_records
          @n_handles = n_handles
          @s_reserved = s_reserved
          @n_description = n_description
          @off_description = off_description
          @n_pal_entries = n_pal_entries
          @device_pixels = device_pixels
          @device_mm = device_mm
          @cb_pixel_format = cb_pixel_format
          @off_pixel_format = off_pixel_format
          @b_open_gl = b_open_gl
          @szl_micrometers = szl_micrometers
          @n_size = n_size
          @trailing = trailing
          @description = description
        end

        attr_reader :bounds, :frame, :signature, :version, :n_bytes, :n_records,
                    :n_handles, :s_reserved, :n_description, :off_description,
                    :n_pal_entries, :device_pixels, :device_mm, :cb_pixel_format,
                    :off_pixel_format, :b_open_gl, :szl_micrometers, :n_size,
                    :trailing

        # The description as UTF-8 (UTF-16LE nDescription chars at offDescription,
        # trailing NULs dropped), or nil when absent or outside the header record.
        # An explicit `description:` given at construction wins.
        def description
          return @description if @description

          bytes = description_bytes
          return unless bytes

          bytes.dup.force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8, invalid: :replace, undef: :replace).sub(/\0+\z/, "")
        end

        # Raw description bytes (2 * nDescription at offDescription from record
        # start), or nil when nDescription is 0 or the range leaves the record.
        def description_bytes
          slice_of_record(off_description, n_description * 2)
        end

        # Raw PIXELFORMATDESCRIPTOR bytes (cbPixelFormat at offPixelFormat), or
        # nil when cbPixelFormat is 0/absent or the range leaves the record.
        def pixel_format_bytes
          slice_of_record(off_pixel_format, cb_pixel_format)
        end

        def self.from_wire(wire)
          new(
            bounds: Geometry::Rect.from_wire(wire.rcl_bounds),
            frame: Geometry::Rect.from_wire(wire.rcl_frame),
            signature: wire.d_signature,
            version: wire.n_version,
            n_bytes: wire.n_bytes,
            n_records: wire.n_records,
            n_handles: wire.n_handles,
            s_reserved: wire.s_reserved,
            n_description: wire.n_description,
            off_description: wire.off_description,
            n_pal_entries: wire.n_pal_entries,
            device_pixels: Geometry::Size.from_wire(wire.szl_device),
            device_mm: Geometry::Size.from_wire(wire.szl_millimeters),
            cb_pixel_format: wire.cb_pixel_format,
            off_pixel_format: wire.off_pixel_format,
            b_open_gl: wire.b_open_gl,
            szl_micrometers: Geometry::Size.from_wire(wire.szl_micrometers),
            n_size: wire.n_size,
            trailing: wire.trailing.to_s
          )
        end

        # The header record bytes as #to_wire writes them now (equal to the source bytes until an edit).
        # Not cached: the fields and `trailing` stay mutable, and the buffers must follow them.
        def record_bytes
          to_wire.to_binary_s
        end

        def to_wire
          Emf::Emr::Binary::Header.new(
            i_type: 1,
            n_size: n_size,
            rcl_bounds: bounds.to_wire,
            rcl_frame: frame.to_wire,
            d_signature: signature,
            n_version: version,
            n_bytes: n_bytes,
            n_records: n_records,
            n_handles: n_handles,
            s_reserved: s_reserved,
            n_description: n_description,
            off_description: off_description,
            n_pal_entries: n_pal_entries,
            szl_device: device_pixels.to_wire,
            szl_millimeters: device_mm.to_wire,
            cb_pixel_format: cb_pixel_format,
            off_pixel_format: off_pixel_format,
            b_open_gl: b_open_gl,
            szl_micrometers: szl_micrometers.to_wire,
            trailing: trailing
          )
        end

        private

        def slice_of_record(offset, length)
          return unless offset&.positive? && length&.positive?

          bytes = record_bytes
          bytes.byteslice(offset, length) if offset + length <= bytes.bytesize
        end
      end
    end
  end
end
