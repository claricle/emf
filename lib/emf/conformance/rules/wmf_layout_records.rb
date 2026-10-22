# frozen_string_literal: true

# WMF rules for the fixed-layout records whose only stated constraints are their exact layout and a
# reserved or enumerated field (MS-WMF 2.3.3 drawing, 2.3.5 state records). The parser keeps any words
# after the last field in `suffix`, so a record can pass decoding with a RecordSize larger than its
# layout. Records whose size is exact at decoding time (the rectangle, point and offset records of
# Binary::FIXED_RECORDS) are checked by wmf.record.declared_size instead.
module Emf
  module Conformance
    module WmfLayoutRules
      WMF = %i[wmf].freeze
      R = Emf::Model::Wmf::Records
      KEPT = "the surplus words stay in the record's suffix, so nothing is dropped"
      COLORREF_RESERVED_SHIFT = 24

      # record class => [parameter bytes the layout defines, section]. Each section lists the record's fields; none lists more.
      LAYOUTS = {
        R::FloodFill => [8, "2.3.3.7 META_FLOODFILL"], R::SetPixel => [8, "2.3.3.19 META_SETPIXEL"],
        R::PatBlt => [12, "2.3.3.12 META_PATBLT"], R::ExcludeClipRect => [8, "2.3.5.2 META_EXCLUDECLIPRECT"],
        R::IntersectClipRect => [8, "2.3.5.3 META_INTERSECTCLIPRECT"], R::OffsetClipRgn => [4, "2.3.5.5 META_OFFSETCLIPRGN"],
        R::RealizePalette => [0, "2.3.5.8 META_REALIZEPALETTE"], R::SetBkColor => [4, "2.3.5.14 META_SETBKCOLOR"],
        R::SetMapperFlags => [4, "2.3.5.18 META_SETMAPPERFLAGS"], R::SetRelAbs => [0, "2.3.5.21 META_SETRELABS"],
        R::SetTextCharExtra => [2, "2.3.5.25 META_SETTEXTCHAREXTRA"], R::SetTextColor => [4, "2.3.5.26 META_SETTEXTCOLOR"],
        R::SetTextJustification => [4, "2.3.5.27 META_SETTEXTJUSTIFICATION"]
      }.freeze
      COLOR_FIELDS = { R::SetBkColor => :color_ref, R::SetTextColor => :color_ref, R::FloodFill => :color, R::SetPixel => :color }.freeze

      module_function

      def layout_size(context)
        each_of(context, *LAYOUTS.keys) do |record|
          surplus = record.suffix.to_s.bytesize
          next if surplus.zero?

          payload, section = LAYOUTS.fetch(record.class)
          words = 3 + ((payload + surplus) / 2)
          note = payload.zero? ? ", the record has no parameters" : ""
          "#{section.split.last} RecordSize is #{words} words, the layout is #{3 + (payload / 2)} words " \
            "(#{surplus} surplus bytes#{note})"
        end
      end

      def raster_operation(context)
        each_of(context, R::PatBlt) do |record|
          value = record.raster_operation.to_i
          if value >= (1 << COLORREF_RESERVED_SHIFT)
            next format("PatBlt RasterOperation 0x%<value>08X has bits set above the 24-bit ternary code, " \
                        "so it is no TernaryRasterOperation value", value: value)
          end

          expected = TernaryRasterOperations.expected(value)
          next if expected.nil? || expected == value

          format("PatBlt RasterOperation 0x%<value>08X is not a TernaryRasterOperation value; " \
                 "operation 0x%<index>02X is 0x%<expected>08X", value: value, index: (value >> 16) & 0xFF, expected: expected)
        end
      end

      def colorref_reserved(context)
        each_of(context, *COLOR_FIELDS.keys) do |record|
          value = record.public_send(COLOR_FIELDS.fetch(record.class)).to_i
          reserved = value >> COLORREF_RESERVED_SHIFT
          next if reserved.zero?

          format("%<name>s ColorRef 0x%<value>08X has Reserved byte 0x%<reserved>02X, MUST be 0x00",
                 name: record.class.name.split("::").last, value: value, reserved: reserved)
        end
      end

      def each_of(context, *classes)
        context.records.each_with_index.filter_map do |record, index|
          next unless classes.any? { |klass| record.instance_of?(klass) }

          message = yield record
          next unless message

          { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
        end
      end
    end

    [
      ["wmf.record.layout_size", :layout_size, :record_layout, WmfLayoutRules::KEPT,
       "MS-WMF 2.3.3.7, 2.3.3.12, 2.3.3.19, 2.3.5.2, 2.3.5.3, 2.3.5.5, 2.3.5.8, 2.3.5.14, 2.3.5.18, 2.3.5.21, 2.3.5.25, " \
       "2.3.5.26, 2.3.5.27 (RecordSize; the record lists no field after its last parameter)"],
      ["wmf.fixed.raster_operation", :raster_operation, :flag_mask, nil,
       "MS-WMF 2.3.3.12 META_PATBLT (RasterOperation); 2.1.1.31 TernaryRasterOperation Enumeration"],
      ["wmf.fixed.colorref_reserved", :colorref_reserved, :reserved_zero, nil,
       "MS-WMF 2.2.2.8 ColorRef Object (Reserved); 2.3.3.7 META_FLOODFILL, 2.3.3.19 META_SETPIXEL, 2.3.5.14 META_SETBKCOLOR, " \
       "2.3.5.26 META_SETTEXTCOLOR"]
    ].each do |id, method, kind, reason, citation|
      Registry.loading.register(id: id, formats: WmfLayoutRules::WMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        WmfLayoutRules.public_send(method, context)
      end
    end
  end
end
