# frozen_string_literal: true

require_relative "record_variants"

# Variants for the bitmap-bearing records (MS-EMF 2.3.1 bitmap records, 2.3.7
# brushes): no bitmap, adjacent, reversed and gapped bitmap buffers, source and
# mask pairs, and offsets or sizes outside the record.
module RecordVariants
  self.catalog = :bitmap
  BMI = [40, 2, -2, 1, 32, 0, 16, 0, 0, 0, 0].pack("VllvvVVllVV").freeze
  BITS = (1..16).to_a.pack("C*").freeze
  XFORM_BK_USAGE = ([1.0, 0.0, 0.0, 1.0, 5.0, -5.0].pack("e6") + [0x00FF8040, 1].pack("V2")).freeze
  BLT_BOUNDS = [-1, -2, 30, 40].freeze
  PTR_NAMES = %w[off_bmi_src cb_bmi_src off_bits_src cb_bits_src].freeze
  MASK_PTR_NAMES = %w[off_bmi_mask cb_bmi_mask off_bits_mask cb_bits_mask].freeze

  # Fixed-part layouts (everything after the 8-byte record header) per record.
  module BitmapLayouts
    def ptrs(pairs, names) = names.zip(pairs.flatten).flat_map { |name, value| u32(name, value) }
    def anon_ptrs(pairs) = pad(pairs.flatten.pack("V*"))
    def dest4 = pad([-3, 4, 5, -6].pack("l<4"))
    def src_origin = pad([7, -8].pack("l<2"))
    def bounds_pad = rectl("rcl_bounds", *BLT_BOUNDS)

    def blt_fixed(pairs, stretch)
      fields = bounds_pad + i32("x_dest", -3) + i32("y_dest", 4) + i32("cx_dest", 5) + i32("cy_dest", -6) +
               u32("dw_rop", 0x00CC0020) + i32("x_src", 7) + i32("y_src", -8) + raw("xform_usage_etc", XFORM_BK_USAGE) +
               ptrs(pairs, PTR_NAMES)
      stretch ? fields + i32("cx_src", 9) + i32("cy_src", -10) : fields
    end

    def stretch_dibits_fixed(pairs)
      bounds_pad + i32("x_dest", -3) + i32("y_dest", 4) + i32("x_src", 7) + i32("y_src", -8) + i32("cx_src", 9) + i32("cy_src", -10) +
        ptrs(pairs, PTR_NAMES) + u32("i_usage_src", 1) + u32("dw_rop", 0x00CC0020) + i32("cx_dest", 11) + i32("cy_dest", -12)
    end

    def brush_fixed(pairs)
      u32("ih_brush", 3) + u32("i_usage", 1) + ptrs(pairs, %w[off_bmi cb_bmi off_bits cb_bits])
    end

    def alpha_fixed(pairs, transparent)
      mid = transparent ? [0x00FF00FF].pack("V") : [0, 0, 0xFF, 1].pack("C4")
      bounds_pad + dest4 + pad(mid) + src_origin + pad(XFORM_BK_USAGE) + anon_ptrs(pairs) + pad([9, -10].pack("l<2"))
    end

    def mask_fixed(pairs)
      bounds_pad + dest4 + pad([0x00CC0020].pack("V")) + src_origin + pad(XFORM_BK_USAGE) + anon_ptrs(pairs.first(2)) +
        pad([2, -3, 1].pack("l<2V")) + anon_ptrs(pairs.last(2))
    end

    def plg_fixed(pairs)
      bounds_pad + pad([1, 2, 30, 4, -5, 60].pack("l<6")) + pad([7, -8, 9, -10].pack("l<4")) + pad(XFORM_BK_USAGE) +
        anon_ptrs(pairs.first(2)) + pad([2, -3, 1].pack("l<2V")) + anon_ptrs(pairs.last(2))
    end

    def dibits_to_device_fixed(pairs)
      bounds_pad + pad([-3, 4, 7, -8, 9, -10].pack("l<6")) + anon_ptrs(pairs) + pad([1, 0, 3].pack("V3"))
    end

    def packed(fields) = fields.filter_map { |field| [field.value].pack(field.pack) if field.pack }.join.b

    # Places buffers after the fixed part; returns [[offset, size] pairs, tail].
    def place(buffers, fixed, order, gap)
      tail = "\0".b * gap
      pairs = Array.new(buffers.size) { [0, 0] }
      (order || buffers.each_index.to_a).each do |index|
        next unless buffers[index]

        pairs[index] = [fixed + tail.bytesize, buffers[index].bytesize]
        tail << buffers[index]
      end
      [pairs, tail]
    end

    # the builder block returns the fixed fields; the result adds the tail and
    # the expected `body`/`trailing` rest. rest_from is the record offset where
    # the Ruby wire's rest field starts (nil: at the end of the fixed part).
    def with_buffers(buffers, rest: "body", rest_from: nil, order: nil, gap: 0, accessors: nil, &builder)
      fixed_bytes = packed(instance_exec(Array.new(buffers.size) { [0, 0] }, &builder))
      pairs, tail = place(buffers, 8 + fixed_bytes.bytesize, order, gap)
      fields = instance_exec(pairs, &builder)
      prefix = rest_from ? packed(fields).byteslice((rest_from - 8)..).to_s : "".b
      checks = accessors ? accessors.zip(pairs.flatten).flat_map { |name, value| check(name, value) } : []
      fields + checks + check(rest, prefix + tail) + pad(tail)
    end

    def shifted(pairs, delta) = pairs.map { |offset, size| [offset + delta, size] }

    # Offset and size malformations of one sample layout.
    def malformed_pointers(sample, options, fixed)
      {
        "buffer offset beyond record" => ->(pairs) { shifted(pairs, 4096) },
        "buffer size beyond record" => ->(pairs) { pairs.map { |offset, _| [offset, UINT_MAX] } },
        "offset inside fixed part" => ->(pairs) { pairs.map { |_, size| [4, size] } }
      }.each do |label, change|
        fields = with_buffers(sample, **options) { |pairs| instance_exec(change.call(pairs), &fixed) }
        malformed(label, fields)
      end
    end
  end
  Entry.include(BitmapLayouts)

  LAYOUTS = [["no bitmap", [nil, nil], nil, 0], ["header then bits", [BMI.b, BITS.b], nil, 0],
             ["bits before header", [BMI.b, BITS.b], [1, 0], 0], ["gap before buffers", [BMI.b, BITS.b], nil, 4],
             ["header only", [BMI.b, nil], nil, 0], ["bits only", [nil, BITS.b], nil, 0]].freeze
  MASK_LAYOUTS = [["no bitmaps", [nil] * 4, nil, 0], ["source only", [BMI.b, BITS.b, nil, nil], nil, 0],
                  ["mask only", [nil, nil, BMI.b, BITS.b], nil, 0], ["source and mask", [BMI.b, BITS.b, BMI.b, BITS.b], nil, 0],
                  ["mask placed before source", [BMI.b, BITS.b, BMI.b, BITS.b], [2, 3, 0, 1], 0]].freeze

  # Declares valid layouts plus offset/size malformations for one record.
  def self.bitmap_entry(name, type, layouts: LAYOUTS, **options, &fixed)
    define(name, type) do
      layouts.each do |label, buffers, order, gap|
        valid(gap.zero? ? label : "#{label} (#{gap}-byte gap)", with_buffers(buffers, order: order, gap: gap, **options, &fixed))
      end
      sample = layouts.fetch(1)[1]
      malformed_pointers(sample, options, fixed)
    end
  end

  bitmap_entry("BitBlt", 76) { |pairs| blt_fixed(pairs, false) }
  bitmap_entry("StretchBlt", 77) { |pairs| blt_fixed(pairs, true) }
  bitmap_entry("StretchDIBits", 81, rest: "trailing") { |pairs| stretch_dibits_fixed(pairs) }
  bitmap_entry("CreateMonoBrush", 93) { |pairs| brush_fixed(pairs) }
  bitmap_entry("CreateDibPatternBrushPt", 94) { |pairs| brush_fixed(pairs) }
  bitmap_entry("AlphaBlend", 114, rest_from: 24, accessors: PTR_NAMES) { |pairs| alpha_fixed(pairs, false) }
  bitmap_entry("TransparentBlt", 116, rest_from: 24, accessors: PTR_NAMES) { |pairs| alpha_fixed(pairs, true) }
  bitmap_entry("SetDibitsToDevice", 80, rest_from: 24, accessors: PTR_NAMES) { |pairs| dibits_to_device_fixed(pairs) }
  bitmap_entry("MaskBlt", 78, layouts: MASK_LAYOUTS, rest_from: 24, accessors: PTR_NAMES + MASK_PTR_NAMES) { |pairs| mask_fixed(pairs) }
  bitmap_entry("PlgBlt", 79, layouts: MASK_LAYOUTS, rest_from: 24, accessors: PTR_NAMES + MASK_PTR_NAMES) { |pairs| plg_fixed(pairs) }
end
