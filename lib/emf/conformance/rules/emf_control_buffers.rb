# frozen_string_literal: true

# EMR_HEADER description / pixel-format buffers and the EMR_EOF palette
# (MS-EMF 2.2.9, 2.2.10, 2.2.22, 2.3.4.1, 2.3.4.2). Reads the buffers through
# the public accessors: header.description_bytes / pixel_format_bytes and the
# EOF wire's palette_bytes.
module Emf
  module Conformance
    module ControlBufferRules
      EMF = %i[emf emf_plus].freeze
      EOF_FIXED = 16 # Type, Size, nPalEntries, offPalEntries; the palette starts right after (GDI writes offset 16)
      PFD_SIZE = 40
      PFD_DOUBLEBUFFER = 0x1
      PFD_SUPPORT_GDI = 0x10
      DRIFT = "the descriptive header buffers are advisory; renderers do not read them"
      PALETTE_DRIFT = "the palette is read from the offset EOF declares, so a mismatched count does not stop rendering"

      module_function

      def header_finding(message) = { message: message, offset: 0, record_index: 0, record_type: RecordTypes::HEADER }

      # EmfDescription is a null-terminated UTF-16LE string of nDescription characters.
      def description_terminator(context)
        bytes = context.header.description_bytes
        return [] if bytes.nil? || bytes.byteslice(-2, 2) == "\0\0".b

        [header_finding("description (#{context.header.n_description} UTF-16 chars) is not null-terminated")]
      end

      # Each buffer must lie at or after the fixed part and the two must not overlap.
      def buffers_overlap(context)
        header = context.header
        return [] unless pixel_format_fields?(header)

        ranges = { "description" => range(header.off_description, header.n_description.to_i * 2),
                   "pixel format" => range(header.off_pixel_format, header.cb_pixel_format) }.compact
        return [] unless ranges.size == 2

        (first, a), (second, b) = ranges.to_a
        return [] unless a.begin < b.end && b.begin < a.end

        [header_finding("#{first} (#{a}) overlaps #{second} (#{b})")]
      end

      def pixel_format_size(context)
        header = context.header
        return [] unless pixel_format_fields?(header)

        size = header.cb_pixel_format.to_i
        return [] if size.zero? || header.off_pixel_format.to_i.zero? || size == PFD_SIZE

        [header_finding("cbPixelFormat is #{size}, a PixelFormatDescriptor is #{PFD_SIZE} bytes")]
      end

      def pixel_format_content(context)
        return [] unless pixel_format_fields?(context.header)

        bytes = context.header.pixel_format_bytes
        return [] if bytes.nil? || bytes.bytesize != PFD_SIZE

        size, version, flags, type = bytes.unpack("vvVC")
        problems = []
        problems << "PixelFormatDescriptor nSize is #{size}, MUST describe its #{PFD_SIZE} bytes" unless size == PFD_SIZE
        problems << "PixelFormatDescriptor nVersion is #{version}, MUST be 1" unless version == 1
        problems << format("PixelFormatDescriptor iPixelType is %d, MUST be 0 (RGBA) or 1 (color index)", type) if type > 1
        both = PFD_DOUBLEBUFFER | PFD_SUPPORT_GDI
        problems << "PixelFormatDescriptor sets both PFD_DOUBLEBUFFER and PFD_SUPPORT_GDI" if flags & both == both
        problems.map { |message| header_finding(message) }
      end

      # nPalEntries in the header counts the palette that the EOF record carries.
      def palette_count(context)
        eof = eof_record(context)
        return [] unless eof

        declared = context.header.n_pal_entries.to_i
        actual = eof.wire.n_pal_entries.to_i
        return [] if declared == actual

        [at(eof, context, "header nPalEntries is #{declared} but EMR_EOF carries #{actual} palette entries")]
      end

      # The nPalEntries LogPaletteEntry objects (4 bytes each) must lie inside the
      # record, after the fixed part and before SizeLast.
      def palette_bounds(context)
        eof = eof_record(context)
        return [] unless eof

        count = eof.wire.n_pal_entries.to_i
        return [] if count.zero?

        offset = eof.wire.off_pal_entries.to_i
        size = context.record_size(eof)
        return [at(eof, context, "palette offset #{offset} is inside the #{EOF_FIXED}-byte fixed part of EMR_EOF")] if offset < EOF_FIXED

        return [] if offset + (4 * count) <= size - 4 && eof.wire.palette_bytes

        [at(eof, context, "palette (#{count} entries at offset #{offset}) does not fit before SizeLast in a #{size}-byte EMR_EOF")]
      end

      # cbPixelFormat/offPixelFormat exist only in a HeaderExtension1 or later header.
      def pixel_format_fields?(header) = HeaderRules.extension1?(header)

      def range(offset, length)
        offset = offset.to_i
        length = length.to_i
        offset...(offset + length) if offset.positive? && length.positive?
      end

      def eof_record(context)
        last = context.records.last
        last if last && context.record_type(last) == RecordTypes::EOF_RECORD
      end

      def at(record, context, message)
        { message: message, offset: record.offset, record_index: context.records.size, record_type: RecordTypes::EOF_RECORD }
      end
    end

    registry = Registry.loading
    {
      "emf.header.description_terminator" => [:description_terminator, "MS-EMF 2.3.4.2", :description_terminator,
                                              ControlBufferRules::DRIFT],
      "emf.header.buffers_overlap" => [:buffers_overlap, "MS-EMF 2.3.4.2", :buffers_overlap, ControlBufferRules::DRIFT],
      "emf.header.pixel_format_size" => [:pixel_format_size, "MS-EMF 2.2.10", :pixel_format_size, ControlBufferRules::DRIFT],
      "emf.header.pixel_format_content" => [:pixel_format_content, "MS-EMF 2.2.22", :pixel_format_content, ControlBufferRules::DRIFT],
      "emf.eof.palette_entries" => [:palette_count, "MS-EMF 2.2.9", :palette_count, ControlBufferRules::PALETTE_DRIFT],
      "emf.eof.palette_bounds" => [:palette_bounds, "MS-EMF 2.3.4.1", :palette_bounds, ControlBufferRules::PALETTE_DRIFT]
    }.each do |id, (method, citation, kind, reason)|
      registry.register(id: id, formats: ControlBufferRules::EMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        ControlBufferRules.public_send(method, context)
      end
    end
  end
end
