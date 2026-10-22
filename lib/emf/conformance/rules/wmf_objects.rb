# frozen_string_literal: true

# WMF object-table lifecycle and playback-DC depth rules over the public record
# sequence (MS-WMF 3.1.4.1 WMF Object Table, 2.3.4 object records, 2.3.5.10
# META_RESTOREDC). One walk replays the table exactly as the spec describes it:
# a created object takes the lowest free index below header NumberOfObjects,
# META_DELETEOBJECT frees it, and later records must refer to live indexes of the
# right object type. Records the model keeps opaque (UnknownRecord) are skipped.
module Emf
  module Conformance
    module WmfObjectRules
      WMF = %i[wmf].freeze
      R = Emf::Model::Wmf::Records
      STOCK_FLAG = 0x8000
      GDI_IGNORES = "GDI skips a record that names an unusable object instead of rejecting the metafile"

      CREATORS = {
        R::CreatePenIndirect => :pen, R::CreateBrushIndirect => :brush, R::CreatePatternBrush => :brush,
        R::DibCreatePatternBrush => :brush, R::CreateFontIndirect => :font, R::CreatePalette => :palette,
        R::CreateRegion => :region
      }.freeze
      REGION_USERS = [R::FillRegion, R::FrameRegion, R::InvertRegion, R::PaintRegion, R::SelectClipRegion].freeze
      BRUSH_USERS = [R::FillRegion, R::FrameRegion].freeze

      # id => [citation, tolerant_reason, kind]
      RULES = {
        "wmf.object.capacity" => ["MS-WMF 3.1.4.1 WMF Object Table, 2.3.2.2 META_HEADER (NumberOfObjects)", nil, :object_capacity],
        "wmf.object.select_reference" => ["MS-WMF 2.3.4.10 META_SELECTOBJECT (ObjectIndex), 3.1.4.1; stock-object selectors " \
                                          "(high bit 0x8000) are an implementation rule, MS-WMF defines no selector encoding",
                                          GDI_IGNORES, :object_reference],
        "wmf.object.delete_reference" => ["MS-WMF 2.3.4.7 META_DELETEOBJECT (ObjectIndex), 3.1.4.1; stock objects are never " \
                                          "deleted (1.1 Glossary), the 0x8000 selector bit is an implementation rule",
                                          GDI_IGNORES, :object_reference],
        "wmf.object.palette_reference" => ["MS-WMF 2.3.4.11 META_SELECTPALETTE (Palette), 3.1.4.1", GDI_IGNORES, :object_type],
        "wmf.object.region_reference" => [
          "MS-WMF 2.3.3.6 META_FILLREGION, 2.3.3.8 META_FRAMEREGION, 2.3.3.9 META_INVERTREGION, " \
          "2.3.3.11 META_PAINTREGION, 2.3.4.9 META_SELECTCLIPREGION (Region), 3.1.4.1", GDI_IGNORES, :object_type
        ],
        "wmf.object.brush_reference" => [
          "MS-WMF 2.3.3.6 META_FILLREGION, 2.3.3.8 META_FRAMEREGION (Brush), 3.1.4.1", GDI_IGNORES, :object_type
        ],
        "wmf.dc.restore_depth" => ["MS-WMF 2.3.5.10 META_RESTOREDC (nSavedDC), 2.3.5.11 META_SAVEDC, 3.1.5; the outcome " \
                                   "of an nSavedDC that names no saved context is an implementation rule, MS-WMF defines " \
                                   "none", GDI_IGNORES, :dc_stack]
      }.freeze

      module_function

      # Replays the record sequence and returns [rule_id, record, index, message] findings.
      def walk(context)
        table = Table.new(context.header.number_of_objects.to_i)
        found = []
        context.records.each_with_index do |record, index|
          table.step(record) { |id, message| found << [id, record, index + 1, message] }
        end
        found
      end

      def findings(context, id)
        walk(context).filter_map do |rule_id, record, index, message|
          next unless rule_id == id

          { message: message, offset: record.offset, record_index: index, record_type: record.type_id.to_i }
        end
      end

      # The conceptual WMF Object Table of MS-WMF 3.1.4.1 plus the SaveDC depth.
      class Table
        def initialize(capacity)
          @capacity = capacity
          @slots = []
          @next_free = 0
          @saved = 0
        end

        def step(record, &)
          kind = CREATORS.find { |klass, _| record.is_a?(klass) }&.last
          return create(kind, &) if kind

          case record
          when R::SelectObject then select_object(record, &)
          when R::DeleteObject then delete_object(record, &)
          when R::SelectPalette then expect(record.object_index, :palette, "palette", "wmf.object.palette_reference", &)
          when R::FillRegion, R::FrameRegion then fill_region(record, &)
          when *REGION_USERS then expect(record.object_index, :region, "region", "wmf.object.region_reference", &)
          when R::SaveDc, R::RestoreDc then device_context(record, &)
          end
        end

        private

        def live(index) = index.negative? ? nil : @slots[index]

        def create(kind)
          @next_free += 1 while @next_free < @capacity && @slots[@next_free]
          if @next_free < @capacity
            @slots[@next_free] = kind
            @next_free += 1
          else
            yield "wmf.object.capacity", "#{kind} object has no free WMF Object Table index; " \
                                         "NumberOfObjects is #{@capacity} and every index is in use"
          end
        end

        def select_object(record)
          index = record.object_index.to_i
          return if index.anybits?(STOCK_FLAG) # stock objects live outside the metafile table
          return if live(index)

          yield "wmf.object.select_reference", "SelectObject index #{index} names no live object in the WMF Object Table"
        end

        def delete_object(record)
          index = record.object_index.to_i
          if index.anybits?(STOCK_FLAG)
            yield "wmf.object.delete_reference", "DeleteObject index 0x#{index.to_s(16).upcase} is a stock object, which cannot be deleted"
          elsif live(index)
            @slots[index] = nil
            @next_free = index if index < @next_free
          else
            yield "wmf.object.delete_reference", "DeleteObject index #{index} names no live object in the WMF Object Table"
          end
        end

        def fill_region(record, &)
          expect(record.region_index, :region, "region", "wmf.object.region_reference", &)
          expect(record.brush_index, :brush, "brush", "wmf.object.brush_reference", &)
        end

        def expect(index, kind, label, id)
          index = index.to_i
          found = live(index)
          if found.nil?
            yield id, "#{label} index #{index} names no live object in the WMF Object Table"
          elsif found != kind
            yield id, "#{label} index #{index} refers to a #{found} object, MUST refer to a #{kind} object"
          end
        end

        def device_context(record, &)
          return @saved += 1 if record.is_a?(R::SaveDc)

          restore(record.saved_dc.to_i, &)
        end

        def restore(saved_dc)
          depth = if saved_dc.negative? then @saved + saved_dc
                  elsif saved_dc.positive? && saved_dc <= @saved then saved_dc - 1
                  end
          if depth&.>=(0)
            @saved = depth
          else
            yield "wmf.dc.restore_depth", "RestoreDc nSavedDC #{saved_dc} names no saved device context (#{@saved} saved)"
          end
        end
      end
    end

    registry = Registry.loading
    WmfObjectRules::RULES.each do |id, (citation, reason, kind)|
      registry.register(id: id, formats: WmfObjectRules::WMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        WmfObjectRules.findings(context, id)
      end
    end
  end
end
