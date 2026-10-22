# frozen_string_literal: true

require_relative "emf_plus_common"

# EMF+ payload rules over the public decoded records and objects: the Size and
# DataSize formulas of the text, image, serializable-object and terminal-server
# records, the fields those records fix, and the bounds of the object payloads
# the public model decodes (EmfPlusImage, EmfPlusFont, EmfPlusStringFormat, ...).
# Findings land on the record that carries the defect; undecodable records are
# read from their raw payload, so a count that runs past the record still gets a
# precise message next to emfplus.record.body_bounds.
module Emf
  module Conformance
    module EmfPlusPayloads
      Records = Emf::EmfPlus::Records
      Objects = Emf::EmfPlus::Objects
      Support = EmfPlusSupport

      HEADER = 12
      ALIGN = 3 # a record may pad its data to 4 bytes (MS-EMFPLUS 2.3.3)
      DRIVER_STRING_OPTIONS = 0x0000000F
      OBJECT_TYPES = (1..9)
      IMAGE_DATA_TYPES = (0..2)
      BITMAP_DATA_TYPES = (0..1)
      METAFILE_DATA_TYPES = (1..5)
      TS_ENUMS = {
        "AntiAliasMode (SmoothingMode)" => [:anti_alias_mode, (0..5)],
        "TextRenderHint (TextRenderingHint)" => [:text_render_hint, (0..5)],
        "CompositingMode" => [:compositing_mode, (0..1)],
        "CompositingQuality" => [:compositing_quality, (1..5)],
        "TextContrast" => [:text_contrast, (0..12)],
        "FilterType" => [:filter_type, [0, 1, 2, 3, 4, 6, 7]],
        "PixelOffset (PixelOffsetMode)" => [:pixel_offset, (0..4)]
      }.freeze

      module_function

      # The record-specific bytes after the 12-byte header, for typed and unknown records alike.
      def payload(record) = record.to_binary.byteslice(HEADER..).to_s

      def u32(payload, offset) = payload.byteslice(offset, 4)&.unpack1("V")

      def name(record) = Support.type_name(record)

      # Size and DataSize each in `minimum..minimum + 3` (the data may carry up to 3 padding bytes), or nil.
      def padded_sizes(record, data_minimum)
        size = Support.size_of(record)
        data_size = Support.data_size_of(record)
        problems = []
        problems << "DataSize is #{data_size}, MUST be #{data_minimum} plus up to 3 padding bytes" unless
          (data_minimum..(data_minimum + ALIGN)).cover?(data_size)
        problems << "Size is #{size}, MUST be #{data_minimum + HEADER} plus up to 3 padding bytes" unless
          ((data_minimum + HEADER)..(data_minimum + HEADER + ALIGN)).cover?(size)
        problems
      end

      def exact_sizes(record, data_expected)
        size = Support.size_of(record)
        data_size = Support.data_size_of(record)
        problems = []
        problems << "DataSize is #{data_size}, MUST be #{data_expected}" unless data_size == data_expected
        problems << "Size is #{size}, MUST be #{data_expected + HEADER}" unless size == data_expected + HEADER
        problems
      end

      def sized(located, problems, formula)
        return if problems.empty?

        "#{name(located.record)} #{problems.join(' and ')} (#{formula})"
      end

      # --- text -----------------------------------------------------------

      def driver_string_size(located)
        record = located.record
        return unless record.type == Records::DrawDriverString::TYPE

        data = payload(record)
        count = u32(data, 12)
        return unless count

        matrix = u32(data, 8) == 1
        minimum = (count * 10) + 16 + (matrix ? 24 : 0)
        sized(located, padded_sizes(record, minimum),
              "GlyphCount #{count}: DataSize = GlyphCount * 10 + #{matrix ? 40 : 16}")
      end

      def driver_string_matrix(located)
        return unless located.record.type == Records::DrawDriverString::TYPE

        value = u32(payload(located.record), 8)
        return if value.nil? || [0, 1].include?(value)

        "DrawDriverString MatrixPresent is #{value}, MUST be 0 or 1"
      end

      def driver_string_options(located)
        return unless located.record.type == Records::DrawDriverString::TYPE

        value = u32(payload(located.record), 4)
        return if value.nil? || value.nobits?(~DRIVER_STRING_OPTIONS)

        format("DrawDriverString DriverStringOptionsFlags 0x%<value>08X sets bits outside the four DriverStringOptions flags",
               value: value)
      end

      def draw_string_size(located)
        record = located.record
        return unless record.type == Records::DrawString::TYPE

        length = u32(payload(record), 8)
        return unless length

        sized(located, padded_sizes(record, (length * 2) + 28), "Length #{length}: DataSize = Length * 2 + 28")
      end

      # --- images ---------------------------------------------------------

      def draw_image_size(located)
        record = located.record
        compressed = record.flags.anybits?(0x4000)
        case record.type
        when Records::DrawImage::TYPE
          sized(located, exact_sizes(record, compressed ? 0x20 : 0x28), "the C flag selects EmfPlusRect or EmfPlusRectF")
        when Records::DrawImagePoints::TYPE
          sized(located, image_points_sizes(record, compressed), "the P and C flags select the point format")
        end
      end

      # EmfPlusPointR elements are 1 or 2 bytes per coordinate, so for P the text's 0x24 is the writer's figure;
      # a DataSize that matches the decoded points (padded or not) is accepted too.
      def image_points_sizes(record, compressed)
        return exact_sizes(record, compressed ? 0x28 : 0x34) unless record.flags.anybits?(0x0800)
        return exact_sizes(record, 0x24) if Support.data_size_of(record) == 0x24 || !Support.typed?(record)

        padded_sizes(record, record.body.num_bytes)
      end

      # --- serializable objects -------------------------------------------

      def serializable_size(located)
        record = located.record
        return unless record.is_a?(Records::SerializableObject)

        problems = exact_sizes(record, record.buffer_size + 0x14)
        problems << "BufferSize #{record.buffer_size} is not a multiple of 4" unless (record.buffer_size % 4).zero?
        sized(located, problems, "DataSize = BufferSize + 0x14, Size = BufferSize + 0x20")
      end

      def serializable_guid(located)
        record = located.record
        return unless record.is_a?(Records::SerializableObject)
        return if Emf::EmfPlus::Effects.lookup(record.object_guid)

        "SerializableObject ObjectGUID #{record.object_guid} is not an image effect identifier"
      end

      def serializable_buffer(located)
        record = located.record
        return unless record.is_a?(Records::SerializableObject) && Emf::EmfPlus::Effects.lookup(record.object_guid)

        effect = record.effect
        return unless effect.respond_to?(:trailing) && !effect.trailing.empty?

        "SerializableObject Buffer holds #{effect.trailing.bytesize} bytes beyond its #{record.object_guid} effect parameter block"
      rescue Emf::ParseError => e
        "SerializableObject Buffer does not hold its effect parameter block: #{e.message}"
      end

      # --- terminal server ------------------------------------------------

      def ts_clip_size(located)
        record = located.record
        return unless record.is_a?(Records::SetTSClip)

        count = record.rect_count
        if record.compressed?
          # The text fixes 4 bytes per rectangle and also describes 1-2 bytes per coordinate; only the shared lower bound holds.
          return if Support.data_size_of(record) >= count * 4 && Support.size_of(record) >= (count * 4) + HEADER

          "SetTSClip DataSize #{Support.data_size_of(record)} is below #{count * 4} (NumRects #{count} at 4 bytes each, C set)"
        else
          sized(located, exact_sizes(record, count * 8), "NumRects #{count}, 8 bytes per rectangle (C clear)")
        end
      end

      def ts_graphics_size(located)
        record = located.record
        return unless record.is_a?(Records::SetTSGraphics)

        data_size = Support.data_size_of(record)
        problems = exact_sizes(record, record.palette? ? data_size : 36)
        problems.reject! { |problem| problem.start_with?("DataSize") } if record.palette?
        sized(located, problems, record.palette? ? "T set: Size = 0x30 + the Palette size" : "T clear: DataSize 0x24, Size 0x30")
      end

      def ts_graphics_palette(located)
        record = located.record
        return unless record.is_a?(Records::SetTSGraphics) && record.palette?
        return if exact_palette?(record.palette) && record.decoded_palette

        "SetTSGraphics Palette of #{record.palette.bytesize} bytes is not exactly one EmfPlusPalette (8 + PaletteCount * 4 bytes)"
      end

      # PaletteCount sized the whole palette; check it before decoding so a huge count never reaches the array reader.
      def exact_palette?(bytes) = bytes.bytesize >= 8 && bytes.bytesize == 8 + (bytes.unpack1("@4V") * 4)

      def ts_graphics_enums(located)
        record = located.record
        return unless record.is_a?(Records::SetTSGraphics)

        TS_ENUMS.filter_map do |label, (reader, domain)|
          value = record.public_send(reader)
          next if domain.include?(value)

          "SetTSGraphics #{label} value #{value} is outside #{domain_text(domain)}"
        end
      end

      def domain_text(domain) = domain.is_a?(Range) ? "#{domain.first}..#{domain.last}" : domain.join(", ")

      # --- object payloads --------------------------------------------------

      def object_type(located)
        record = located.record
        return unless record.is_a?(Records::Object) && !OBJECT_TYPES.cover?(record.object_type)

        "EmfPlusObject ObjectType is #{record.object_type}, MUST be 1..9 (Brush..CustomLineCap)"
      end

      # The object this record completes (a chain's last chunk, or a single record), or nil.
      def completed_object(stream, located)
        record = located.record
        return unless record.is_a?(Records::Object) && record.emf_object_id < Emf::EmfPlus::ObjectTable::SLOTS

        index = located.handle.stream_index
        object = stream.objects.lookup(record.emf_object_id, at: index + 1)
        object unless object.nil? || object.equal?(stream.objects.lookup(record.emf_object_id, at: index))
      end

      def object_payload(stream, located)
        logical = completed_object(stream, located)
        return unless logical

        logical.body
        nil
      rescue Emf::ParseError => e
        "EmfPlusObject (object type #{logical.object_type}, ID #{logical.emf_object_id}) payload does not fit: #{e.message}"
      end

      def image_fields(stream, located)
        logical = completed_object(stream, located)
        return unless logical&.object_type == Objects::IMAGE

        body = logical.body
        problems = image_problems(body)
        problems.map { |problem| "EmfPlusImage (object ID #{logical.emf_object_id}) #{problem}" }
      rescue Emf::ParseError
        nil # reported by emfplus.object.payload
      end

      def image_problems(image)
        problems = []
        problems << "Type #{image.image_type} is not an ImageDataType (0..2)" unless IMAGE_DATA_TYPES.cover?(image.image_type)
        bitmap = image.bitmap
        problems.concat(bitmap_problems(bitmap)) if bitmap
        metafile = image.metafile
        if metafile && !METAFILE_DATA_TYPES.cover?(metafile.metafile_type)
          problems << "metafile Type #{metafile.metafile_type} is not a MetafileDataType (1..5)"
        end
        problems
      end

      def bitmap_problems(bitmap)
        problems = []
        problems << "bitmap Type #{bitmap.bitmap_type} is not a BitmapDataType (0..1)" unless BITMAP_DATA_TYPES.cover?(bitmap.bitmap_type)
        problems << "bitmap Stride #{bitmap.stride} is not a multiple of 4" if bitmap.bitmap_type.zero? && !(bitmap.stride % 4).zero?
        problems
      end

      def per_object(context, &)
        stream = context.metafile.emf_plus_stream
        return [] unless stream

        Support.records(context).flat_map do |located|
          Array(yield(stream, located)).map { |message| Support.finding(located, message) }
        end
      end
    end

    {
      "emfplus.draw.driver_string" => ["MS-EMFPLUS 2.3.4.6", :driver_string_size, :driver_string_size],
      "emfplus.draw.driver_string_matrix" => ["MS-EMFPLUS 2.3.4.6", :driver_string_matrix_present, :driver_string_matrix],
      "emfplus.draw.driver_string_options" => ["MS-EMFPLUS 2.3.4.6", :driver_string_options, :driver_string_options],
      "emfplus.draw.string" => ["MS-EMFPLUS 2.3.4.14", :draw_string_size, :draw_string_size],
      "emfplus.draw.image" => ["MS-EMFPLUS 2.3.4", :draw_image_size, :draw_image_size],
      "emfplus.object.serializable" => ["MS-EMFPLUS 2.3.5.2", :serializable_size, :serializable_size],
      "emfplus.object.serializable_guid" => ["MS-EMFPLUS 2.3.5.2", :serializable_guid, :serializable_guid],
      "emfplus.object.serializable_buffer" => ["MS-EMFPLUS 2.3.5.2", :serializable_buffer, :serializable_buffer],
      "emfplus.terminal.clip" => ["MS-EMFPLUS 2.3.8.1", :ts_clip_size, :ts_clip_size],
      "emfplus.terminal.graphics" => ["MS-EMFPLUS 2.3.8.2", :ts_graphics_size, :ts_graphics_size],
      "emfplus.terminal.graphics_palette" => ["MS-EMFPLUS 2.3.8.2", :ts_graphics_palette, :ts_graphics_palette],
      "emfplus.terminal.graphics_enums" => ["MS-EMFPLUS 2.3.8.2", :ts_graphics_enums, :ts_graphics_enums],
      "emfplus.object.type" => ["MS-EMFPLUS 2.3.5.1", :object_type, :object_type]
    }.each do |id, (citation, kind, check)|
      EmfPlusSupport.per_record(id: id, citation: citation, kind: kind) { |located| EmfPlusPayloads.public_send(check, located) }
    end

    {
      "emfplus.object.payload" => ["MS-EMFPLUS 2.3.5.1", :object_payload, :object_payload],
      "emfplus.image.fields" => ["MS-EMFPLUS 2.2.1.4", :image_fields, :image_fields]
    }.each do |id, (citation, kind, check)|
      Registry.loading.register(id: id, formats: [:emf_plus], citation: citation, kind: kind, tolerant_reason: nil) do |context|
        EmfPlusPayloads.per_object(context) { |stream, located| EmfPlusPayloads.public_send(check, stream, located) }
      end
    end
  end
end
