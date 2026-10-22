# frozen_string_literal: true

# Object creation and manipulation rules (MS-EMF 2.3.7, 2.3.8, 2.1.31, 2.2.17-2.2.20).
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module ObjectRules
      EMF = %i[emf emf_plus].freeze
      DEFAULT_PALETTE = 0x8000000F
      STOCK = ((0x80000000..0x80000008).to_a + (0x8000000A..0x80000013).to_a).freeze # MS-EMF 2.1.31
      # Record types that put a new handle in the object table, and the wire field that holds it.
      CREATE = { 38 => :ih_pen, 39 => :ih_brush, 49 => :ih_pal, 82 => :ih_object, 93 => :ih_brush,
                 94 => :ih_brush, 95 => :ih_pen, 99 => :ih_cs, 122 => :ih_cs }.freeze
      # Records that name an existing handle: type => wire field.
      SELECT = { 37 => :ih_object, 48 => :ih_pal, 100 => :ih_cs }.freeze
      DELETE = { 40 => :ih_object, 101 => :ih_cs }.freeze
      USE = { 50 => :ih_pal, 51 => :ih_pal }.freeze
      REFERENCES = SELECT.merge(DELETE).merge(USE).freeze
      FIXED_SIZES = { 38 => 28, 39 => 24, 48 => 12, 100 => 12, 111 => 24 }.freeze
      PS_GEOMETRIC = 0x10000
      PS_NULL = 5
      PS_ALTERNATE = 8
      BS_SOLID = 0
      BS_NULL = 1
      BS_HATCHED = 2
      MAX_PALETTE = 0x400
      MIN_FONT_RECORD = 12 + 320 # fixed part plus a LogFontPanose (2.3.7.8)
      COSMETIC_WIDTH = "GDI writes PS_SOLID pens wider than 1 and renders them at that width; 165 corpus files do this"
      PEN_BRUSH = "the same section's brush table lists BS_PATTERN and BS_DIBPATTERN as supported for the pen; GDI writes " \
                  "DIB-pattern geometric pens (5 corpus files)"
      FONT_SHORT = "the same section says a LogFont MAY be present instead of a LogFontExDv, so a shorter elw is not uniformly invalid"
      UNKNOWN_HANDLE = "readers skip a SELECTOBJECT or DELETEOBJECT whose handle is not in the table and keep drawing"

      module_function

      # nil when the record has no such field, or its body is too short to decode it.
      def field(record, name)
        wire = record.wire
        wire.respond_to?(name) ? wire.public_send(name).to_i : nil
      rescue ArgumentError
        nil
      end

      def at(record, index, message)
        { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
      end

      def each_of(context, types)
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          yield record, index, type if types.include?(type)
        end
      end

      def hex(value) = format("0x%08X", value)

      def fixed_size(context)
        found = []
        each_of(context, FIXED_SIZES.keys) do |record, index, type|
          size = context.record_size(record)
          next if size == FIXED_SIZES.fetch(type)

          found << at(record, index, "#{RecordTypes.name(type)} Size is #{size}, MUST be #{FIXED_SIZES.fetch(type)}")
        end
        found
      end

      # PenStyle (2.1.25): line style 0-8, cap 0/0x100/0x200, join 0/0x1000/0x2000, type 0/PS_GEOMETRIC.
      def font_size(context)
        found = []
        each_of(context, [82]) do |record, index, _type|
          size = context.record_size(record)
          next if size >= MIN_FONT_RECORD

          found << at(record, index, "EXTCREATEFONTINDIRECTW Size #{size} leaves #{size - 12} bytes for elw, " \
                                     "less than a LogFontPanose (#{MIN_FONT_RECORD - 12})")
        end
        found
      end

      def pen_style_problem(style)
        return "line style #{style & 0xFF} is outside PS_SOLID..PS_ALTERNATE" if (style & 0xFF) > PS_ALTERNATE
        return "end cap #{hex(style & 0xF00)} is not round, square or flat" unless [0, 0x100, 0x200].include?(style & 0xF00)
        return "line join #{hex(style & 0xF000)} is not round, bevel or miter" unless [0, 0x1000, 0x2000].include?(style & 0xF000)
        return "pen type #{hex(style & 0xF0000)} is not PS_COSMETIC or PS_GEOMETRIC" unless [0, PS_GEOMETRIC].include?(style & 0xF0000)
        return "bits #{hex(style & 0xFFF00000)} are outside the PenStyle enumeration" unless style.nobits?(0xFFF00000)

        "PS_ALTERNATE is applicable only to PS_COSMETIC pens" if (style & 0xFF) == PS_ALTERNATE && style.anybits?(PS_GEOMETRIC)
      end

      def pen_style(context)
        found = []
        each_of(context, [38, 95]) do |record, index, type|
          style = field(record, :pen_style)
          problem = style && pen_style_problem(style)
          found << at(record, index, "#{RecordTypes.name(type)} PenStyle #{hex(style)}: #{problem}") if problem
        end
        found
      end

      def pen_width(record, type)
        return record.wire.width.x.to_i if type == 38 && record.wire.respond_to?(:width)

        field(record, :width)
      end

      def cosmetic_width(context)
        found = []
        each_of(context, [38, 95]) do |record, index, type|
          style = field(record, :pen_style)
          next if style.nil? || style.anybits?(PS_GEOMETRIC)

          width = pen_width(record, type)
          next if width.nil? || width == 1

          found << at(record, index, "#{RecordTypes.name(type)} is a PS_COSMETIC pen with width #{width}, MUST be 1")
        end
        found
      end

      def brush_style(context)
        found = []
        each_of(context, [39]) do |record, index, _type|
          style = field(record, :brush_style)
          next if style.nil? || [BS_SOLID, BS_NULL, BS_HATCHED].include?(style)

          found << at(record, index, "CREATEBRUSHINDIRECT BrushStyle #{style} MUST be BS_SOLID, BS_HATCHED or BS_NULL")
        end
        found
      end

      def extpen_brush_problem(pen_style, brush, hatch)
        if pen_style.anybits?(PS_GEOMETRIC)
          "a PS_GEOMETRIC pen MUST use BS_SOLID or BS_HATCHED" unless [BS_SOLID, BS_HATCHED].include?(brush) ||
                                                                      (brush == BS_NULL && (pen_style & 0xFF) == PS_NULL)
        elsif brush == BS_HATCHED && ![0x8, 0xA].include?(hatch)
          "a cosmetic BS_HATCHED pen MUST use HS_SOLIDTEXTCLR or HS_SOLIDBKCLR, not #{hatch}"
        end
      end

      def extpen_brush(context)
        found = []
        each_of(context, [95]) do |record, index, _type|
          style = field(record, :pen_style)
          brush = field(record, :brush_style)
          next if style.nil? || brush.nil?

          problem = extpen_brush_problem(style, brush, field(record, :brush_hatch))
          found << at(record, index, "EXTCREATEPEN brush style #{brush}: #{problem}") if problem
        end
        found
      end

      def palette_version(context)
        found = []
        each_of(context, [49]) do |record, index, _type|
          version = field(record, :version)
          next if version.nil? || version == 0x300

          found << at(record, index, "CREATEPALETTE LogPalette Version is #{format('0x%04X', version)}, MUST be 0x0300")
        end
        found
      end

      def palette_entries(context)
        found = []
        each_of(context, [49, 51]) do |record, index, type|
          count = field(record, :entry_count)
          next if count.nil?
          next if count.positive? && (type == 49 || count <= MAX_PALETTE)

          found << at(record, index,
                      "#{RecordTypes.name(type)} NumberOfEntries is #{count}, MUST be #{type == 49 ? '> 0' : "> 0 and <= #{MAX_PALETTE}"}")
        end
        found
      end

      # Palette records whose entry array is sized by a count: the record Size must match the layout.
      PALETTE_FIXED = { 49 => 16, 50 => 20 }.freeze

      def palette_size(context)
        found = []
        each_of(context, PALETTE_FIXED.keys) do |record, index, type|
          count = field(record, :entry_count)
          next if count.nil?

          expected = PALETTE_FIXED.fetch(type) + (4 * count)
          size = context.record_size(record)
          next if size == expected

          found << at(record, index, "#{RecordTypes.name(type)} holds #{count} palette entries, so Size MUST be #{expected}, not #{size}")
        end
        found
      end

      def index_zero(context)
        found = []
        each_of(context, [37, 40, 48]) do |record, index, type|
          next unless field(record, REFERENCES.fetch(type))&.zero?

          found << at(record, index, "#{RecordTypes.name(type)} object index 0 is reserved for the metafile itself, MUST NOT be used")
        end
        found
      end

      def delete_stock(context)
        found = []
        each_of(context, [40]) do |record, index, _type|
          handle = field(record, :ih_object)
          next unless STOCK.include?(handle)

          found << at(record, index, "DELETEOBJECT names the stock object #{hex(handle)}, which cannot be deleted")
        end
        found
      end

      # A stock index is a valid operand of SELECTOBJECT; SELECTPALETTE takes only DEFAULT_PALETTE.
      def stock_ok?(type, handle)
        return handle == DEFAULT_PALETTE if type == 48

        type == 37 && STOCK.include?(handle)
      end

      def handle_range(context)
        limit = context.header.n_handles.to_i
        found = []
        each_of(context, REFERENCES.keys) do |record, index, type|
          handle = field(record, REFERENCES.fetch(type))
          next if handle.nil? || handle.zero? || handle < limit || stock_ok?(type, handle)
          next if type == 40 && STOCK.include?(handle) # emf.object.delete_stock reports it

          found << at(record, index,
                      "#{RecordTypes.name(type)} names object index #{hex(handle)}, " \
                      "not below header Handles (#{limit}) and not a stock object")
        end
        found
      end

      # Walks the stream in order, keeping the live handle table.
      def lifecycle(context)
        live = {}
        found = []
        context.records.each_with_index do |record, index|
          type = context.record_type(record)
          name = CREATE[type] || REFERENCES[type]
          handle = name && field(record, name)
          next if handle.nil?

          if CREATE.key?(type)
            live[handle] = index + 1
          else
            problem = missing_handle(live, type, handle)
            found << at(record, index, "#{RecordTypes.name(type)} #{problem}") if problem
            live.delete(handle) if DELETE.key?(type)
          end
        end
        found
      end

      def missing_handle(live, _type, handle)
        return if handle.zero? || handle >= 0x80000000 || live.key?(handle) # zero and stock are other rules' business

        "uses object index #{handle}, which the stream never created or already deleted"
      end
    end

    registry = Registry.loading
    {
      "emf.object.fixed_size" => [:fixed_size, "MS-EMF 2.3.7", :object_fixed_size, nil],
      "emf.object.font_size" => [:font_size, "MS-EMF 2.3.7.8", :font_size, ObjectRules::FONT_SHORT],
      "emf.object.pen_style" => [:pen_style, "MS-EMF 2.1.25", :pen_style, nil],
      "emf.object.pen_cosmetic_width" => [:cosmetic_width, "MS-EMF 2.2.19", :pen_cosmetic_width, ObjectRules::COSMETIC_WIDTH],
      "emf.object.brush_style" => [:brush_style, "MS-EMF 2.3.7.1", :brush_style, nil],
      "emf.object.extpen_brush" => [:extpen_brush, "MS-EMF 2.2.20", :extpen_brush, ObjectRules::PEN_BRUSH],
      "emf.object.palette_version" => [:palette_version, "MS-EMF 2.3.7.6", :palette_version, nil],
      "emf.object.palette_entries" => [:palette_entries, "MS-EMF 2.3.8.4", :palette_entries, nil],
      "emf.object.palette_size" => [:palette_size, "MS-EMF 2.3.7.6", :palette_size, nil],
      "emf.object.index_zero" => [:index_zero, "MS-EMF 2.3.8.5", :index_zero, nil],
      "emf.object.delete_stock" => [:delete_stock, "MS-EMF 2.3.8.3", :delete_stock, nil],
      "emf.object.handle_range" => [:handle_range, "MS-EMF 2.3.8", :handle_range, nil],
      "emf.object.lifecycle" => [:lifecycle, "MS-EMF 2.3.8", :object_lifecycle, ObjectRules::UNKNOWN_HANDLE]
    }.each do |id, (method, citation, kind, reason)|
      registry.register(id: id, formats: ObjectRules::EMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        ObjectRules.public_send(method, context)
      end
    end
  end
end
