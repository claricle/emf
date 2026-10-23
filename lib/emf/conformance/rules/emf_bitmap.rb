# frozen_string_literal: true

# Bitmap record rules (MS-EMF 2.3.1.x, MS-WMF 2.2.2.3 / 2.2.2.9). The BMI and bits
# bytes are read from the record's own bytes: only offsets, lengths and the fixed
# BITMAPINFOHEADER fields, never the pixels.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module BitmapRules
      PALETTE_COLORS = "GDI writes PALETTEINDEX and PALETTERGB colors with 0x01 or 0x02 in the Reserved byte, and readers resolve them"
      EMF = %i[emf emf_plus].freeze
      Slot = Struct.new(:name, :usage, :off_bmi, :cb_bmi, :off_bits, :cb_bits)
      SOURCE = Slot.new("source", 80, 84, 88, 92, 96)
      DIB_SOURCE = Slot.new("source", 64, 48, 52, 56, 60)
      MASK = Slot.new("mask", 108, 112, 116, 120, 124)
      PLG_SOURCE = Slot.new("source", 92, 96, 100, 104, 108)
      PLG_MASK = Slot.new("mask", 120, 124, 128, 132, 136)
      GAMUT_INTENTS = [1, 2, 4, 8].freeze
      V5_HEADER_SIZE = 124

      # type => fixed size, bitmap slots and the offsets of the type's other checked fields.
      LAYOUTS = {
        76 => { name: "EMR_BITBLT", size: 100, slots: [SOURCE], rop: 40, colorrefs: [76] },
        77 => { name: "EMR_STRETCHBLT", size: 108, slots: [SOURCE], rop: 40, colorrefs: [76] },
        78 => { name: "EMR_MASKBLT", size: 128, slots: [SOURCE, MASK], rop4: 40, colorrefs: [76] },
        79 => { name: "EMR_PLGBLT", size: 140, slots: [PLG_SOURCE, PLG_MASK], colorrefs: [88] },
        80 => { name: "EMR_SETDIBITSTODEVICE", size: 76, slots: [DIB_SOURCE], scans: 72 },
        81 => { name: "EMR_STRETCHDIBITS", size: 80, slots: [DIB_SOURCE], rop: 68 },
        114 => { name: "EMR_ALPHABLEND", size: 108, slots: [SOURCE], blend: 40, extents: [32, 36, 100, 104], colorrefs: [76] },
        116 => { name: "EMR_TRANSPARENTBLT", size: 108, slots: [SOURCE], colorrefs: [40, 76] }
      }.freeze

      BIT_COUNTS = [0, 1, 4, 8, 16, 24, 32].freeze
      COMPRESSIONS = [0, 1, 2, 3, 4, 5, 0xB, 0xC, 0xD].freeze
      RLE = [1, 2, 0xC, 0xD].freeze
      STRIDE_BASED = [0, 3, 0xB].freeze

      UNLOCATABLE = "the record Size still delimits the stream, so a bitmap that cannot be located is skipped by readers"

      # id => [citation, kind, severity, tolerant_reason]
      RULES = {
        "emf.bitmap.record_size" => ["MS-EMF 2.3.1", :bitmap_size, :error, "the parser recovers a short bitmap record as raw bytes"],
        "emf.bitmap.usage" => ["MS-EMF 2.1.9", :bitmap_usage, :error, nil],
        "emf.bitmap.bmi_range" => ["MS-EMF 2.3.1", :bmi_range, :error, UNLOCATABLE],
        "emf.bitmap.bits_range" => ["MS-EMF 2.3.1", :bits_range, :error, UNLOCATABLE],
        "emf.bitmap.buffer_fixed_overlap" => ["MS-EMF 2.3.1", :buffer_fixed_overlap, :error, nil],
        "emf.bitmap.buffer_overlap" => ["MS-EMF 2.3.1", :buffer_overlap, :error, nil],
        "emf.bitmap.bmi_header_size" => ["MS-WMF 2.2.2.9", :bmi_header_size, :error, UNLOCATABLE],
        "emf.bitmap.bmi_extent" => ["MS-WMF 2.2.2.3", :bmi_extent, :error, nil],
        "emf.bitmap.bmi_planes" => ["MS-WMF 2.2.2.3", :bmi_planes, :error, nil],
        "emf.bitmap.bmi_bitcount" => ["MS-WMF 2.1.1.3", :bmi_bitcount, :error, nil],
        "emf.bitmap.bmi_compression" => ["MS-WMF 2.1.1.7", :bmi_compression, :error, nil],
        "emf.bitmap.bits_length" => ["MS-WMF 2.2.2.9", :bits_length, :error, nil],
        "emf.bitmap.color_table" => ["MS-WMF 2.2.2.3", :color_table, :error,
                                     "readers cap an oversized ColorUsed to the colour table BitCount allows (note under ColorUsed), " \
                                     "so the corrupted fixtures still decode"],
        "emf.bitmap.color_table_length" => ["MS-WMF 2.2.2.9", :color_table_length, :warning, nil],
        "emf.bitmap.bmi_v5_intent" => ["MS-WMF 2.2.2.5", :bmi_v5_intent, :error, nil],
        "emf.bitmap.colorref_reserved" => ["MS-WMF 2.2.2.8", :colorref_reserved, :error, nil],
        "emf.bitmap.colorref_palette" => ["MS-WMF 2.2.2.8", :colorref_reserved, :error, PALETTE_COLORS],
        "emf.bitmap.mask_monochrome" => ["MS-EMF 2.3.1.2", :mask_monochrome, :error, nil],
        "emf.bitmap.raster_operation" => ["MS-EMF 2.3.1.1", :raster_operation, :error, nil],
        "emf.bitmap.rop4_reserved" => ["MS-EMF 2.3.1.2", :rop4_reserved, :warning, nil],
        "emf.bitmap.blend_operation" => ["MS-EMF 2.3.1.4", :blend_operation, :error, nil],
        "emf.bitmap.alpha_format" => ["MS-EMF 2.3.1.4", :alpha_format, :error, nil],
        "emf.bitmap.positive_extent" => ["MS-EMF 2.3.1.4", :positive_extent, :error, nil]
      }.freeze

      # Findings of one metafile, grouped by rule id; computed once and shared by all rules.
      CACHE = ObjectSpace::WeakMap.new

      module_function

      def findings(context, id)
        # The WeakMap holds its values weakly: keep a strong reference until the lookup is done.
        grouped = CACHE[context] || (CACHE[context] = analyze(context))
        grouped.fetch(id, [])
      end

      def analyze(context)
        out = Hash.new { |hash, id| hash[id] = [] }
        context.records.each_with_index do |record, index|
          layout = LAYOUTS[context.record_type(record)]
          Scan.new(record, index, layout, context.record_size(record), out).run if layout
        end
        out
      end

      # BITMAPINFOHEADER / BITMAPCOREHEADER checks and the bits-length arithmetic; mixed into Scan.
      module HeaderChecks
        private

        def header_fields(bmi)
          count = bmi[2] - bmi[1]
          size = count >= 4 ? u32(bmi[1]) : nil
          unless size && (size == 12 || size >= 40) && size <= count
            add("emf.bitmap.bmi_header_size", "#{bmi[0]} header size #{size.inspect} is not 12 or 40+ within its #{count} bytes")
            return
          end
          size == 12 ? core_header(bmi[1]) : info_header(bmi[1])
        end

        def core_header(pos)
          fields = { planes: @bytes.unpack1("v", offset: pos + 8), bit_count: @bytes.unpack1("v", offset: pos + 10),
                     width: @bytes.unpack1("v", offset: pos + 4), height: @bytes.unpack1("v", offset: pos + 6) }
          check_depth(fields)
          fields.merge(compression: 0, image_size: 0, header_size: 12, color_used: 0)
        end

        def info_header(pos)
          fields = { width: s32(pos + 4), height: s32(pos + 8), planes: @bytes.unpack1("v", offset: pos + 12),
                     bit_count: @bytes.unpack1("v", offset: pos + 14), compression: u32(pos + 16), image_size: u32(pos + 20),
                     color_used: u32(pos + 32), header_size: u32(pos) }
          v5_intent(pos) if fields[:header_size] == V5_HEADER_SIZE
          add("emf.bitmap.bmi_extent", "BMI Width #{fields[:width]} MUST be positive") unless fields[:width].positive?
          add("emf.bitmap.bmi_extent", "BMI Height MUST NOT be zero") if fields[:height].zero?
          check_depth(fields)
          compression(fields)
          fields
        end

        def check_depth(fields)
          add("emf.bitmap.bmi_planes", "BMI Planes #{fields[:planes]} MUST be 1") unless fields[:planes] == 1
          return if BIT_COUNTS.include?(fields[:bit_count])

          add("emf.bitmap.bmi_bitcount",
              "BMI BitCount #{fields[:bit_count]} is not in the BitCount enumeration")
        end

        def compression(fields)
          code = fields[:compression]
          unless COMPRESSIONS.include?(code)
            add("emf.bitmap.bmi_compression",
                "BMI Compression #{code} is not in the Compression enumeration")
          end
          return unless fields[:height].negative? && RLE.include?(code)

          add("emf.bitmap.bmi_compression", "top-down BMI (negative Height) MUST NOT use compression #{code}")
        end

        # Uncompressed: at least the stride formula's length; compressed: exactly the BMI ImageSize.
        def bits_length(slot, header)
          count = u32(slot.cb_bits)
          return if count.zero?

          if STRIDE_BASED.include?(header[:compression])
            expected = stride_bytes(header)
            if count < expected
              add("emf.bitmap.bits_length",
                  "#{slot.name} cbBits #{count} is shorter than the #{expected} bytes the BMI stride needs")
            end
          elsif count != header[:image_size]
            add("emf.bitmap.bits_length", "#{slot.name} cbBits #{count} MUST equal the BMI ImageSize #{header[:image_size]}")
          end
        end

        def v5_intent(pos)
          intent = u32(pos + 108)
          return if GAMUT_INTENTS.include?(intent)

          add("emf.bitmap.bmi_v5_intent", "BitmapV5Header Intent #{intent} is not in the GamutMappingIntent enumeration")
        end

        # The colour table is whatever the BMI buffer holds after the header: RGBQuads, or 16-bit palette
        # indexes under DIB_PAL_COLORS; a BI_BITFIELDS BitmapInfoHeader also keeps its three masks there.
        def color_table(slot, bmi, header, packed)
          size = header[:header_size]
          usage = u32(slot.usage)
          return if size < 40 || usage > 1 || [4, 5].include?(header[:compression]) || bmi[2] - bmi[1] < size

          entry = usage.zero? ? 4 : 2
          held = bmi[2] - bmi[1] - size
          held -= 12 if header[:compression] == 3 && size == 40 && held >= 12
          check_tables(slot, header, held, entry, packed)
        end

        # A packed bitmap with a ColorUsed is judged by emf.bitmap.color_table (MUST, error) on this same shortfall, so
        # the table-length rule stays silent for it.
        def check_tables(slot, header, held, entry, packed)
          if packed
            check_color_used(slot, header, held, entry)
            return unless header[:color_used].zero?
          end
          check_color_table_length(slot, header, held, entry)
        end

        def table_entries(header)
          limit = header[:bit_count] < 16 ? 1 << header[:bit_count] : nil
          used = header[:color_used]
          return limit.to_i if used.zero?

          limit ? [used, limit].min : used
        end

        # "In a packed bitmap, the ColorUsed value MUST be either 0 or the actual size of the color table."
        # Only a ColorUsed that outruns the buffer is certain: real producers (test-164/165) pad the BMI buffer.
        def check_color_used(slot, header, held, entry)
          return if header[:color_used].zero?

          want = table_entries(header)
          return if held >= want * entry

          add("emf.bitmap.color_table",
              "#{slot.name} packed bitmap ColorUsed #{header[:color_used]} needs #{want * entry} colour table bytes, " \
              "the BMI buffer holds only #{held} after its header")
        end

        def check_color_table_length(slot, header, held, entry)
          return unless [1, 4, 8].include?(header[:bit_count])

          need = table_entries(header) * entry
          return if held >= need

          add("emf.bitmap.color_table_length",
              "#{slot.name} BMI holds #{held} colour table bytes, BitCount #{header[:bit_count]} / ColorUsed " \
              "#{header[:color_used]} SHOULD give #{need}")
        end

        def stride_bytes(header)
          lines = header[:height].abs
          lines = [lines, u32(@layout[:scans])].min if @layout[:scans]
          return 0 unless header[:width].positive?

          (((header[:width] * header[:planes] * header[:bit_count]) + 31) & ~31) / 8 * lines
        end
      end

      # One record's checks; every method adds to `out[rule id]`.
      class Scan
        include HeaderChecks

        def initialize(record, index, layout, size, out)
          @record = record
          @index = index
          @layout = layout
          @size = size
          @out = out
          @bytes = record.to_binary_s
        end

        def run
          if @size < @layout[:size]
            return add("emf.bitmap.record_size",
                       "#{@layout[:name]} Size #{@size} is smaller than its #{@layout[:size]}-byte fixed part")
          end
          return if @bytes.bytesize < @layout[:size]

          ranges = @layout[:slots].flat_map { |slot| slot_checks(slot) }
          overlaps(ranges.compact)
          other_fields
        end

        private

        def add(id, message)
          @out[id] << { message: message, offset: @record.offset, record_index: @index + 1, record_type: @record.type_id.to_i }
        end

        def u32(pos) = @bytes.unpack1("V", offset: pos)
        def s32(pos) = @bytes.unpack1("l<", offset: pos)

        def slot_checks(slot)
          usage = u32(slot.usage)
          add("emf.bitmap.usage", "#{@layout[:name]} #{slot.name} UsageSrc/UsageMask #{usage} is not a DIBColors value") if usage > 2
          bmi = range(slot, "#{slot.name} BMI", slot.off_bmi, slot.cb_bmi, "emf.bitmap.bmi_range")
          bits = range(slot, "#{slot.name} bits", slot.off_bits, slot.cb_bits, "emf.bitmap.bits_range")
          header = bmi && header_fields(bmi)
          header_checks(slot, bmi, bits, header) if header
          @header ||= header if slot.name == "source"
          [bmi, bits]
        end

        def header_checks(slot, bmi, bits, header)
          bits_length(slot, header)
          color_table(slot, bmi, header, bits && bits[1] == bmi[2])
          return unless slot.name == "mask" && header[:bit_count] != 1

          add("emf.bitmap.mask_monochrome", "mask bitmap BitCount #{header[:bit_count]} is not monochrome (1)")
        end

        # [label, from, to] of a non-empty buffer range, or nil when empty or out of the record.
        def range(slot, label, off_at, cb_at, id)
          offset = u32(off_at)
          count = u32(cb_at)
          return if count.zero?

          if offset + count > @size
            add(id, "#{label} range #{offset}+#{count} runs past the #{@size}-byte record")
            return
          end
          if offset < @layout[:size]
            add("emf.bitmap.buffer_fixed_overlap",
                "#{label} offset #{offset} lies inside the #{@layout[:size]}-byte fixed part")
          end
          [label, offset, offset + count, slot]
        end

        def overlaps(ranges)
          reach = nil
          ranges.sort_by { |range| range[1] }.each do |range|
            add("emf.bitmap.buffer_overlap", "#{range[0]} overlaps #{reach[0]}") if reach && range[1] < reach[2]
            reach = range if reach.nil? || range[2] > reach[2]
          end
        end

        def other_fields
          rop = @layout[:rop]
          if rop && u32(rop) >> 24 != 0
            add("emf.bitmap.raster_operation",
                "raster operation 0x#{u32(rop).to_s(16)} has bits set above the 24-bit ternary code")
          end
          rop4 = @layout[:rop4]
          if rop4 && @bytes.unpack1(
            "v", offset: rop4
          ) != 0
            add("emf.bitmap.rop4_reserved",
                "ROP4 reserved word 0x#{@bytes.unpack1('v', offset: rop4).to_s(16)} SHOULD be 0")
          end
          colorrefs
          blend if @layout[:blend]
          @layout[:extents]&.each do |pos|
            add("emf.bitmap.positive_extent", "extent at offset #{pos} is #{s32(pos)}, MUST be greater than zero") unless s32(pos).positive?
          end
        end

        def colorrefs
          @layout[:colorrefs]&.each do |pos|
            reserved = @bytes.getbyte(pos + 3)
            next if reserved.zero?

            id = [1, 2].include?(reserved) ? "emf.bitmap.colorref_palette" : "emf.bitmap.colorref_reserved"
            add(id, "ColorRef at offset #{pos} has Reserved byte #{reserved}, MUST be 0")
          end
        end

        def blend
          pos = @layout[:blend]
          operation, _flags, _alpha, format = @bytes.byteslice(pos, 4).unpack("C4")
          unless operation.zero?
            add("emf.bitmap.blend_operation",
                "BlendOperation #{operation} is not 0 (AC_SRC_OVER, the only defined value)")
          end
          add("emf.bitmap.alpha_format", "AlphaFormat #{format} is neither 0 nor AC_SRC_ALPHA (1)") unless [0, 1].include?(format)
          return unless format == 1 && @header && @header[:bit_count] != 32

          add("emf.bitmap.alpha_format", "AC_SRC_ALPHA needs a 32 bits-per-pixel source, BMI says #{@header[:bit_count]}")
        end
      end
    end

    BitmapRules::RULES.each do |id, (citation, kind, severity, reason)|
      Registry.loading.register(id: id, formats: BitmapRules::EMF, citation: citation, kind: kind, severity: severity,
                                tolerant_reason: reason) { |context| BitmapRules.findings(context, id) }
    end
  end
end
