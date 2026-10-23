# frozen_string_literal: true

# WMF bitmap, text, palette, region, escape and embedded-EMF buffer rules over typed public
# records (MS-WMF 2.3.1 bitmap, 2.3.3 drawing, 2.3.4 object, 2.3.5 state and 2.3.6 escape
# records). Only values the model exposes are judged: records the model keeps opaque
# (UnknownRecord, escape subtypes without a view, undecodable bytes) are preserved and never
# reported, except a text record the parser kept verbatim because its StringLength is negative, and no rule
# here needs the declared record size.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module WmfBufferRules
      WMF = %i[wmf].freeze
      R = Emf::Model::Wmf::Records
      EE = Emf::Wmf::EmbeddedEmf
      UINT16 = 0xFFFF
      INT16 = 0x7FFF
      DIB_RECORDS = [R::DibBitBlt, R::DibStretchBlt, R::SetDibToDev, R::StretchDib].freeze
      BITMAP16_RECORDS = [R::BitBlt, R::StretchBlt].freeze
      PALETTE_RECORDS = [R::CreatePalette, R::SetPalEntries, R::AnimatePalette].freeze
      CLIPPED_OR_OPAQUE = 0x0006
      REGION_HEADER_BYTES = 22
      SEQUENCE_REASONS = %i[sequence_mismatch limit_exceeded remaining_mismatch record_count_mismatch incomplete].freeze

      PRESERVED = "bytes are preserved verbatim; a consumer skips the unusable part instead of rejecting the record"

      module_function

      def dib_layout(context)
        each_of(context, *DIB_RECORDS) do |record|
          next if record.bitmap.nil? || record.typed_image

          "#{name(record)} DeviceIndependentBitmap does not decode: header, color table or pixel extent disagrees " \
            "with the #{record.bitmap.bytesize} bytes carried"
        end
      end

      def bitmap16_layout(context)
        each_of(context, *BITMAP16_RECORDS) do |record|
          next if record.bitmap.nil? || record.typed_image

          "#{name(record)} Bitmap16 does not decode: Width, Height, Planes, BitsPixel or pixel extent disagrees " \
            "with the #{record.bitmap.bytesize} bytes carried"
        end
      end

      def text_length(context)
        each_of(context, R::TextOut) do |record|
          count = record.text.bytesize
          if count > INT16
            "#{name(record)} string is #{count} bytes, StringLength is a signed 16-bit count"
          elsif (count + record.padding.bytesize).odd?
            "#{name(record)} string and padding take #{count + record.padding.bytesize} bytes, MUST be word aligned"
          end
        end
      end

      # A text record with a negative StringLength cannot be framed as text, so the parser keeps it as an
      # UnknownRecord (Wmf::Recovery); the sign is read from its own bytes.
      def text_negative(context)
        context.records.each_with_index.filter_map do |record, index|
          next unless record.is_a?(R::UnknownRecord) && Emf::Wmf::Recovery.record(record.raw_bytes, record.type_id, nil)&.last == 1003

          count_at = Emf::Wmf::Recovery::TEXT_COUNTS.fetch(record.type_id & 0xFF).first
          { message: "#{record.type_id & 0xFF == 0x32 ? 'ExtTextOut' : 'TextOut'} StringLength is " \
                     "#{record.raw_bytes.byteslice(count_at, 2).unpack1('s<')}, MUST NOT be negative",
            offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
        end
      end

      def text_spacing(context)
        each_of(context, R::ExtTextOut) do |record|
          next if record.dx.nil? || record.dx.size == record.text.bytesize

          "ExtTextOut has #{record.dx.size} Dx entries for a #{record.text.bytesize}-byte string, MUST match StringLength"
        end
      end

      def text_rectangle(context)
        each_of(context, R::ExtTextOut) do |record|
          wanted = record.options.to_i.anybits?(CLIPPED_OR_OPAQUE)
          next if wanted == !record.rectangle.nil?

          if wanted
            "ExtTextOut options select ETO_OPAQUE or ETO_CLIPPED but the Rectangle is absent"
          else
            "ExtTextOut has a Rectangle but its options select neither ETO_OPAQUE nor ETO_CLIPPED"
          end
        end
      end

      def palette_count(context)
        each_of(context, *PALETTE_RECORDS, R::ResizePalette) do |record|
          count = record.is_a?(R::ResizePalette) ? record.entry_count : record.entries.size
          next if count.is_a?(Integer) && count.between?(0, UINT16)

          "#{name(record)} entry count #{count.inspect} does not fit the unsigned 16-bit field"
        end
      end

      def palette_entries(context)
        each_of(context, *PALETTE_RECORDS) do |record|
          bad = record.entries.find do |entry|
            [entry.red, entry.green, entry.blue, entry.flags].any? { |value| !value.is_a?(Integer) || !value.between?(0, 0xFF) }
          end
          "#{name(record)} holds a PaletteEntry with a component outside 0..255" if bad
        end
      end

      def palette_start(context)
        each_of(context, R::CreatePalette) do |record|
          format("CreatePalette Start is 0x%04X, MUST be 0x0300", record.start.to_i) unless record.start == 0x0300
        end
      end

      def region_scans(context)
        each_of(context, R::CreateRegion) do |record|
          scans = record.scans
          if scans.size > INT16
            "region has #{scans.size} scans, ScanCount is a signed 16-bit count"
          elsif (scan = scans.find { |item| item.lines.size * 2 > UINT16 })
            "region scan at Top #{scan.top} has #{scan.lines.size * 2} scan points, the count is an unsigned 16-bit field"
          end
        end
      end

      def region_size(context)
        each_of(context, R::CreateRegion) do |record|
          next if record.scans.size > INT16 || record.scans.any? { |scan| scan.lines.size * 2 > UINT16 }

          size = REGION_HEADER_BYTES + record.scans.sum { |scan| 8 + (scan.lines.size * 4) }
          "region needs #{size} bytes, RegionSize is a signed 16-bit field" if size > INT16
        end
      end

      def escape_count(context)
        each_of(context, R::Escape) do |record|
          bytes = record.data.bytesize
          if bytes > UINT16
            "Escape carries #{bytes} data bytes, ByteCount is an unsigned 16-bit field"
          elsif record.padding.nil? == bytes.odd?
            "Escape data of #{bytes} bytes #{bytes.odd? ? 'lacks' : 'has'} a padding byte, the record MUST stay word aligned"
          end
        end
      end

      def embedded_segment(context)
        each_of(context, R::Escape) do |record|
          record.embedded_emf_segment
          nil
        rescue EE::Invalid => e
          "embedded EMF escape segment is invalid: #{e.reason}" unless e.reason == :not_embedded_emf
        end
      end

      def embedded_sequence(context)
        embedded_runs(context) do |run|
          "embedded EMF escape sequence is inconsistent: #{run.error}" if SEQUENCE_REASONS.include?(run.error)
        end
      end

      def embedded_checksum(context)
        embedded_runs(context) do |run|
          next unless run.stream && !run.stream.checksum_valid

          "embedded EMF stream does not match the Checksum of its first escape segment"
        end
      end

      # Findings for each run of consecutive 0x000F escapes, positioned at its first record.
      def embedded_runs(context)
        EE.sequences(context.records).filter_map do |run|
          message = yield run
          next unless message

          record = context.records[run.first_record]
          { message: message, offset: record.offset, record_index: run.first_record + 1, record_type: record.type_id.to_i }
        end
      end

      def name(record) = record.class.name.split("::").last

      def each_of(context, *classes)
        context.records.each_with_index.filter_map do |record, index|
          next unless classes.any? { |klass| record.is_a?(klass) }

          message = yield record
          next unless message

          { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
        end
      end
    end

    # [id, method, citation, kind, tolerant_reason]
    [
      ["wmf.bitmap.dib_layout", :dib_layout,
       "MS-WMF 2.2.2.9 DeviceIndependentBitmap Object; 2.3.1.2.1 META_DIBBITBLT, 2.3.1.3.1 " \
       "META_DIBSTRETCHBLT (Target), 2.3.1.4 META_SETDIBTODEV, 2.3.1.6 META_STRETCHDIB (DIB)",
       :buffer_layout, WmfBufferRules::PRESERVED],
      ["wmf.bitmap.bitmap16_layout", :bitmap16_layout, "MS-WMF 2.2.2.1 Bitmap16 Object; 2.3.1.1.1 META_BITBLT, 2.3.1.5.1 META_STRETCHBLT " \
                                                       "(Target)",
       :buffer_layout, WmfBufferRules::PRESERVED],
      ["wmf.text.length", :text_length, "MS-WMF 2.3.3.20 META_TEXTOUT, 2.3.3.5 META_EXTTEXTOUT (StringLength, String)",
       :string_length, nil],
      ["wmf.text.negative_length", :text_negative,
       "MS-WMF 2.3.3.20 META_TEXTOUT, 2.3.3.5 META_EXTTEXTOUT (StringLength, String)", :string_length,
       "the parser keeps the record verbatim as an opaque record; readers (LibreOffice) import the file"],
      ["wmf.text.spacing_count", :text_spacing, "MS-WMF 2.3.3.5 META_EXTTEXTOUT (Dx)", :array_counts, nil],
      ["wmf.text.rectangle_options", :text_rectangle, "MS-WMF 2.3.3.5 META_EXTTEXTOUT (fwOpts, Rectangle)", :field_dependency,
       "readers ignore a Rectangle the options do not select"],
      ["wmf.palette.entry_count", :palette_count,
       "MS-WMF 2.3.4.3 META_CREATEPALETTE, 2.3.5.19 META_SETPALENTRIES, 2.3.5.1 META_ANIMATEPALETTE, " \
       "2.3.5.9 META_RESIZEPALETTE (NumberOfEntries); 2.2.1.3 Palette Object (NumberOfEntries)",
       :array_counts, nil],
      ["wmf.palette.entry_fields", :palette_entries,
       "MS-WMF 2.2.2.13 PaletteEntry Object; 2.2.1.3 Palette Object (aPaletteEntries); " \
       "2.3.4.3 META_CREATEPALETTE, 2.3.5.19 META_SETPALENTRIES, 2.3.5.1 META_ANIMATEPALETTE",
       :coordinate_range, nil],
      ["wmf.palette.start", :palette_start, "MS-WMF 2.2.1.3 Palette Object (Start, MUST be 0x0300 for META_CREATEPALETTE); 2.3.4.3 " \
                                            "META_CREATEPALETTE", :fixed_value,
       "readers ignore the Start of a created palette"],
      ["wmf.region.scan_counts", :region_scans, "MS-WMF 2.2.1.5 Region Object (ScanCount, aScans), 2.2.2.21 Scan Object; 2.3.4.6 " \
                                                "META_CREATEREGION", :array_counts, nil],
      ["wmf.region.size", :region_size, "MS-WMF 2.2.1.5 Region Object (RegionSize); 2.3.4.6 META_CREATEREGION", :buffer_layout, nil],
      ["wmf.escape.byte_count", :escape_count, "MS-WMF 2.3.6.1 META_ESCAPE (ByteCount, EscapeData)", :byte_count, nil],
      ["wmf.escape.embedded_emf.segment", :embedded_segment, "MS-WMF 2.3.6.25 META_ESCAPE_ENHANCED_METAFILE", :buffer_layout,
       "producers write other data under Escape 0x000F (Micrografx Flowcharter); readers skip an embedded stream they " \
       "cannot use and play the WMF records"],
      ["wmf.escape.embedded_emf.sequence", :embedded_sequence,
       "MS-WMF 2.3.6.25 META_ESCAPE_ENHANCED_METAFILE (CommentRecordCount, CurrentRecordSize, " \
       "RemainingBytes, EnhancedMetafileDataSize)",
       :array_counts, nil],
      ["wmf.escape.embedded_emf.checksum", :embedded_checksum, "MS-WMF 2.3.6.25 META_ESCAPE_ENHANCED_METAFILE (Checksum)", :checksum,
       "readers do not validate the embedded stream Checksum"]
    ].each do |id, method, citation, kind, reason|
      Registry.loading.register(id: id, formats: WmfBufferRules::WMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        WmfBufferRules.public_send(method, context)
      end
    end
  end
end
