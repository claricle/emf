# frozen_string_literal: true

module Emf
  module SpecSupport
    # Spec-layout bodies for the EMF+ drawing and fill records (2.3.4). Each
    # sample is a record built from the field order in the spec.
    module EmfPlusDrawFill
      COMPRESSED = 0x4000
      SOLID = 0x8000
      RELATIVE = 0x0800

      def f32(*values) = values.pack("e*")
      def s16(*values) = values.pack("s<*")
      def u32(*values) = values.pack("V*")

      # (5, -2) as Integer7 + Integer15, (-3, 63) as two Integer7, (256, 1) as Integer15 + Integer7.
      def relative_points = "\x05\xFF\xFE\x7D\x3F\x81\x00\x01".b

      def draw_fill_samples = draw_samples + fill_samples

      def draw_samples
        argb = u32(0xFF332211)
        [
          { klass: :Clear, type: 0x4009, flags: 0, body: argb },
          { klass: :DrawRects, type: 0x400B, flags: COMPRESSED | 3, body: u32(2) + s16(1, 2, 3, 4, 5, 6, 7, 8) },
          { klass: :DrawRects, type: 0x400B, flags: 3, body: u32(1) + f32(1.5, 2.5, 3.5, 4.5) },
          { klass: :DrawLines, type: 0x400D, flags: COMPRESSED | 0x2000 | 4, body: u32(2) + s16(1, 2, -3, -4) },
          { klass: :DrawLines, type: 0x400D, flags: RELATIVE | 4, body: u32(3) + relative_points },
          { klass: :DrawEllipse, type: 0x400F, flags: COMPRESSED | 5, body: s16(10, 20, 30, 40) },
          { klass: :DrawEllipse, type: 0x400F, flags: 5, body: f32(10, 20, 30, 40) },
          { klass: :DrawPie, type: 0x4011, flags: COMPRESSED | 6, body: f32(45, -90) + s16(1, 2, 3, 4) },
          { klass: :DrawArc, type: 0x4012, flags: 6, body: f32(45, 90) + f32(1, 2, 3, 4) },
          { klass: :DrawPath, type: 0x4015, flags: 7, body: u32(9) },
          { klass: :DrawClosedCurve, type: 0x4017, flags: 8, body: f32(0.5) + u32(3) + f32(1, 2, 3, 4, 5, 6) },
          { klass: :DrawClosedCurve, type: 0x4017, flags: RELATIVE | 8, body: f32(0.5) + u32(3) + relative_points },
          { klass: :DrawCurve, type: 0x4018, flags: COMPRESSED | 9, body: f32(0.25) + u32(1, 2, 3) + s16(1, 2, 3, 4, 5, 6) },
          { klass: :DrawBeziers, type: 0x4019, flags: 10, body: u32(4) + f32(1, 2, 3, 4, 5, 6, 7, 8) }
        ]
      end

      def fill_samples
        argb = u32(0xFF332211)
        [
          { klass: :FillRects, type: 0x400A, flags: SOLID | COMPRESSED, body: argb + u32(1) + s16(1, 2, 3, 4) },
          { klass: :FillRects, type: 0x400A, flags: 0, body: u32(5, 1) + f32(1, 2, 3, 4) },
          { klass: :FillPolygon, type: 0x400C, flags: SOLID | RELATIVE, body: argb + u32(3) + relative_points },
          { klass: :FillEllipse, type: 0x400E, flags: SOLID, body: argb + f32(1, 2, 3, 4) },
          { klass: :FillPie, type: 0x4010, flags: COMPRESSED, body: u32(5) + f32(10, 20) + s16(1, 2, 3, 4) },
          { klass: :FillRegion, type: 0x4013, flags: SOLID | 11, body: argb },
          { klass: :FillPath, type: 0x4014, flags: 12, body: u32(5) },
          { klass: :FillClosedCurve, type: 0x4016, flags: SOLID | COMPRESSED | 0x2000,
            body: argb + f32(0.5) + u32(3) + s16(1, 2, 3, 4, 5, 6) }
        ]
      end
    end
  end
end
