# frozen_string_literal: true

module Emf
  module SpecSupport
    # One edit per typed EMF+ record: a valid unedited body, the edits to apply
    # through Record#with, and the Record Flags the edit must produce.
    module EmfPlusEditExamples
      Example = Struct.new(:flags, :body, :edit, :flags_after, keyword_init: true)

      module_function

      def u32(*values) = values.pack("V*")
      def f32(*values) = values.pack("e*")
      def i16(*values) = values.pack("s<*")
      def utf16(text) = text.encode(Encoding::UTF_16LE).b
      def rect_f(left, top, wide, high) = { x: left, y: top, width: wide, height: high }
      def point_f(across, down) = { x: across, y: down }

      def for_class(klass)
        all.fetch(klass) { raise KeyError, "no EMF+ edit example for #{klass}" }
      end

      def all
        records = Emf::EmfPlus::Records
        { records::Header => example(1, u32(0xDBC01002, 0, 96, 96), { logical_dpi_x: 300, dual: false }, 0),
          records::EndOfFile => example(0, "", { flags: 5 }, 5),
          records::Comment => example(0, "abcd", { private_data: "wxyz!" }, 0),
          records::GetDC => example(0, "", { flags: 5 }, 5),
          records::Object => example(0x0305, "abcdefgh", { flags: 0x0307, object_data: "abcdefghij" }, 0x0307) }
          .merge(drawing).merge(filling).merge(state).merge(clip_and_transform).merge(text_and_image)
      end

      def example(flags, body, edit, flags_after = flags)
        Example.new(flags: flags, body: body.b, edit: edit, flags_after: flags_after)
      end

      def drawing
        records = Emf::EmfPlus::Records
        one_rect = f32(1, 2, 3, 4)
        two_points = f32(1, 2, 3, 4)
        { records::Clear => example(0, [1, 2, 3, 4].pack("C*"), { color: { red: 9 } }),
          records::DrawRects => example(0, u32(1) + one_rect,
                                        { item_count: 2, emf_object_id: 9,
                                          rect_data: { float_rects: [rect_f(1.0, 2.0, 3.0, 4.0), rect_f(5.0, 6.0, 7.0, 8.0)] } }, 9),
          records::DrawLines => example(0, u32(2) + two_points,
                                        { item_count: 3, close_shape: true,
                                          point_data: { float_points: Array.new(3) { |i| point_f(i * 2.0, i + 1.0) } } }, 0x2000),
          records::DrawEllipse => example(0x0004, one_rect,
                                          { rect_data: { float_rects: [rect_f(9.0, 8.0, 7.0, 6.0)] }, emf_object_id: 6 }, 6),
          records::DrawPie => example(0x4003, f32(10, 20) + i16(1, 2, 3, 4), { start_angle: 45.0, emf_object_id: 9 }, 0x4009),
          records::DrawArc => example(0x0003, f32(10, 20) + one_rect, { sweep_angle: 90.0, emf_object_id: 12 }, 12),
          records::DrawPath => example(0x0007, u32(2), { pen_id: 9, emf_object_id: 3 }, 3),
          records::DrawClosedCurve => example(0, f32(0.5) + u32(2) + two_points,
                                              { tension: 1.5, item_count: 1, point_data: { float_points: [point_f(7.0, 8.0)] } }),
          records::DrawCurve => example(0, f32(0.5) + u32(0, 1, 2) + two_points, { tension: 2.5, offset: 1 }),
          records::DrawBeziers => example(0, u32(2) + two_points,
                                          { item_count: 4, point_data: { float_points: Array.new(4) { |i| point_f(i * 1.0, 2.0) } } }) }
      end

      def filling
        records = Emf::EmfPlus::Records
        one_rect = f32(1, 2, 3, 4)
        two_points = f32(1, 2, 3, 4)
        { records::FillRects => example(0, u32(0xFF0000FF, 1) + one_rect, { brush_id: 7, solid_color: true }, 0x8000),
          records::FillPolygon => example(0, u32(0xFF0000FF, 2) + two_points, { brush_id: 7, emf_object_id: 2 }, 2),
          records::FillEllipse => example(0x8000, u32(0xFF0000FF) + one_rect, { solid_color: false, brush_id: 3 }, 0),
          records::FillPie => example(0, u32(1) + f32(10, 20) + one_rect, { start_angle: 5.0, solid_color: true }, 0x8000),
          records::FillRegion => example(0x8004, u32(0xFF0000FF), { brush_id: 11, emf_object_id: 6 }, 0x8006),
          records::FillPath => example(0x0004, u32(0xFF0000FF), { brush_id: 11, solid_color: true }, 0x8004),
          records::FillClosedCurve => example(0, u32(1) + f32(0.5) + u32(2) + two_points, { tension: 0.25, winding: true }, 0x2000) }
      end

      def state
        records = Emf::EmfPlus::Records
        { records::SetRenderingOrigin => example(0, [3, 4].pack("l<*"), { x: -9 }),
          records::SetAntiAliasMode => example(0x0005, "", { anti_alias: false, smoothing_mode: 9 }, 0x0012),
          records::SetTextRenderingHint => example(0x7F05, "", { text_rendering_hint: 3 }, 0x7F03),
          records::SetTextContrast => example(0x5123, "", { text_contrast: 0x0ABC }, 0x5ABC),
          records::SetInterpolationMode => example(0x7F05, "", { interpolation_mode: 3 }, 0x7F03),
          records::SetPixelOffsetMode => example(0x7F05, "", { pixel_offset_mode: 3 }, 0x7F03),
          records::SetCompositingMode => example(0x7F05, "", { compositing_mode: 1 }, 0x7F01),
          records::SetCompositingQuality => example(0x7F05, "", { compositing_quality: 2 }, 0x7F02),
          records::Save => example(0, u32(1), { stack_index: 7 }),
          records::Restore => example(0, u32(1), { stack_index: 7 }),
          records::BeginContainer => example(0x0003, f32(1, 2, 3, 4, 5, 6, 7, 8) + u32(1),
                                             { stack_index: 5, page_unit: 2, src_rect: { width: 9.0 } }, 0x0002),
          records::BeginContainerNoParams => example(0, u32(1), { stack_index: 7 }),
          records::EndContainer => example(0, u32(1), { stack_index: 7 }),
          records::SetTSGraphics => example(0, [1, 2, 3, 4].pack("C*") + i16(5, 6) + [7, 8, 9].pack("vCC") + f32(1, 0, 0, 1, 0, 0),
                                            { anti_alias_mode: 2, vga_palette: true }, 0x0002) }
      end

      def clip_and_transform
        records = Emf::EmfPlus::Records
        matrix = f32(1, 0, 0, 1, 5, 6)
        { records::ResetClip => example(0, "", { flags: 3 }, 3),
          records::OffsetClip => example(0, f32(1, 2), { dx: 4.0 }),
          records::SetClipRect => example(0x0105, f32(1, 2, 3, 4), { clip_rect: { x: 9.0 }, combine_mode: 2 }, 0x0205),
          records::SetClipPath => example(0x0107, "", { emf_object_id: 9, combine_mode: 3 }, 0x0309),
          records::SetClipRegion => example(0x0107, "", { emf_object_id: 9, combine_mode: 3 }, 0x0309),
          records::SetTSClip => example(0x0001, i16(1, 2, 3, 4), { rect_data: i16(1, 2, 3, 4, 5, 6, 7, 8), rect_count: 2 }, 0x0002),
          records::SetWorldTransform => example(0, matrix, { matrix: { dx: 8.0 } }),
          records::ResetWorldTransform => example(0, "", { flags: 3 }, 3),
          records::MultiplyWorldTransform => example(0x2000, matrix, { post_multiply: false, matrix: { dx: 3.0 } }, 0),
          records::TranslateWorldTransform => example(0, f32(1, 2), { dx: 4.0, post_multiply: true }, 0x2000),
          records::ScaleWorldTransform => example(0, f32(1, 2), { sx: 4.0, post_multiply: true }, 0x2000),
          records::RotateWorldTransform => example(0x2000, f32(30), { angle: 45.0, post_multiply: false }, 0),
          records::SetPageTransform => example(0x0003, f32(2), { page_scale: 4.0, page_unit: 2 }, 0x0002) }
      end

      def text_and_image
        records = Emf::EmfPlus::Records
        { records::DrawString => example(0x8005, u32(7, 8, 2) + f32(1, 2, 3, 4) + utf16("ab"),
                                         { char_count: 3, string_data: utf16("abc"), solid_color: false, font_object_id: 7 }, 0x0007),
          records::DrawDriverString => example(0x8005, u32(7, 1, 0, 2) + [65, 66].pack("v*") + f32(1, 2, 3, 4),
                                               { glyph_count: 3, glyphs: [65, 66, 67], solid_color: false,
                                                 glyph_positions: Array.new(3) { |i| point_f(i * 1.0, 2.0) } }, 0x0005),
          records::DrawImage => example(0x0005, u32(1, 2) + f32(1, 2, 3, 4) + f32(5, 6, 7, 8),
                                        { image_attributes_id: 9, image_object_id: 7 }, 0x0007),
          records::DrawImagePoints => example(0x0005, u32(1, 2) + f32(1, 2, 3, 4) + u32(3) + f32(1, 2, 3, 4, 5, 6),
                                              { image_attributes_id: 4, effect: true }, 0x2005),
          records::SerializableObject => example(0, "#{'G' * 16}#{u32(4)}abcd", { buffer_size: 6, buffer: "abcdef" }) }
      end
    end
  end
end
