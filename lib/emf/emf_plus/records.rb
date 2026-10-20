# frozen_string_literal: true

module Emf
  module EmfPlus
    # Typed views over framed EMF+ records. Types without a class decode to
    # Records::Unknown, which keeps the frame so nothing is dropped.
    module Records
      autoload :Primitives, "emf/emf_plus/records/primitives"
      autoload :Base, "emf/emf_plus/records/base"
      autoload :Unknown, "emf/emf_plus/records/unknown"
      autoload :Header, "emf/emf_plus/records/header"
      autoload :EndOfFile, "emf/emf_plus/records/end_of_file"
      autoload :Comment, "emf/emf_plus/records/comment"
      autoload :GetDC, "emf/emf_plus/records/get_dc"
      autoload :Object, "emf/emf_plus/records/object"

      # Flag mixins shared by several record families.
      autoload :ShapeFlags, "emf/emf_plus/records/shape_flags"
      autoload :FillBrush, "emf/emf_plus/records/fill_brush"
      autoload :CombineModeFlags, "emf/emf_plus/records/clip_transform_flags"
      autoload :PostMultiplyFlag, "emf/emf_plus/records/clip_transform_flags"

      # Drawing and fill
      autoload :Clear, "emf/emf_plus/records/clear"
      autoload :DrawRects, "emf/emf_plus/records/draw_rects"
      autoload :DrawLines, "emf/emf_plus/records/draw_lines"
      autoload :DrawEllipse, "emf/emf_plus/records/draw_ellipse"
      autoload :DrawPie, "emf/emf_plus/records/draw_pie"
      autoload :DrawArc, "emf/emf_plus/records/draw_arc"
      autoload :DrawPath, "emf/emf_plus/records/draw_path"
      autoload :DrawClosedCurve, "emf/emf_plus/records/draw_closed_curve"
      autoload :DrawCurve, "emf/emf_plus/records/draw_curve"
      autoload :DrawBeziers, "emf/emf_plus/records/draw_beziers"
      autoload :FillRects, "emf/emf_plus/records/fill_rects"
      autoload :FillPolygon, "emf/emf_plus/records/fill_polygon"
      autoload :FillEllipse, "emf/emf_plus/records/fill_ellipse"
      autoload :FillPie, "emf/emf_plus/records/fill_pie"
      autoload :FillRegion, "emf/emf_plus/records/fill_region"
      autoload :FillPath, "emf/emf_plus/records/fill_path"
      autoload :FillClosedCurve, "emf/emf_plus/records/fill_closed_curve"

      # State
      autoload :SetRenderingOrigin, "emf/emf_plus/records/set_rendering_origin"
      autoload :SetAntiAliasMode, "emf/emf_plus/records/set_anti_alias_mode"
      autoload :SetTextRenderingHint, "emf/emf_plus/records/set_text_rendering_hint"
      autoload :SetTextContrast, "emf/emf_plus/records/set_text_contrast"
      autoload :SetInterpolationMode, "emf/emf_plus/records/set_interpolation_mode"
      autoload :SetPixelOffsetMode, "emf/emf_plus/records/set_pixel_offset_mode"
      autoload :SetCompositingMode, "emf/emf_plus/records/set_compositing_mode"
      autoload :SetCompositingQuality, "emf/emf_plus/records/set_compositing_quality"
      autoload :Save, "emf/emf_plus/records/save"
      autoload :Restore, "emf/emf_plus/records/restore"
      autoload :BeginContainer, "emf/emf_plus/records/begin_container"
      autoload :BeginContainerNoParams, "emf/emf_plus/records/begin_container_no_params"
      autoload :EndContainer, "emf/emf_plus/records/end_container"
      autoload :SetTSGraphics, "emf/emf_plus/records/set_ts_graphics"

      # Clipping and transform
      autoload :ResetClip, "emf/emf_plus/records/reset_clip"
      autoload :OffsetClip, "emf/emf_plus/records/offset_clip"
      autoload :SetClipRect, "emf/emf_plus/records/set_clip_rect"
      autoload :SetClipPath, "emf/emf_plus/records/set_clip_path"
      autoload :SetClipRegion, "emf/emf_plus/records/set_clip_region"
      autoload :SetTSClip, "emf/emf_plus/records/set_ts_clip"
      autoload :SetWorldTransform, "emf/emf_plus/records/set_world_transform"
      autoload :ResetWorldTransform, "emf/emf_plus/records/reset_world_transform"
      autoload :MultiplyWorldTransform, "emf/emf_plus/records/multiply_world_transform"
      autoload :TranslateWorldTransform, "emf/emf_plus/records/translate_world_transform"
      autoload :ScaleWorldTransform, "emf/emf_plus/records/scale_world_transform"
      autoload :RotateWorldTransform, "emf/emf_plus/records/rotate_world_transform"
      autoload :SetPageTransform, "emf/emf_plus/records/set_page_transform"

      # Text and image
      autoload :DrawString, "emf/emf_plus/records/draw_string"
      autoload :DrawDriverString, "emf/emf_plus/records/draw_driver_string"
      autoload :DrawImage, "emf/emf_plus/records/draw_image"
      autoload :DrawImagePoints, "emf/emf_plus/records/draw_image_points"
      autoload :SerializableObject, "emf/emf_plus/records/serializable_object"

      module_function

      def registry
        @registry ||= [
          Header, EndOfFile, Comment, GetDC, Object,
          Clear, DrawRects, DrawLines, DrawEllipse, DrawPie, DrawArc, DrawPath, DrawClosedCurve, DrawCurve, DrawBeziers,
          FillRects, FillPolygon, FillEllipse, FillPie, FillRegion, FillPath, FillClosedCurve,
          SetRenderingOrigin, SetAntiAliasMode, SetTextRenderingHint, SetTextContrast, SetInterpolationMode,
          SetPixelOffsetMode, SetCompositingMode, SetCompositingQuality, Save, Restore, BeginContainer,
          BeginContainerNoParams, EndContainer, SetTSGraphics,
          ResetClip, OffsetClip, SetClipRect, SetClipPath, SetClipRegion, SetTSClip,
          SetWorldTransform, ResetWorldTransform, MultiplyWorldTransform, TranslateWorldTransform,
          ScaleWorldTransform, RotateWorldTransform, SetPageTransform,
          DrawString, DrawDriverString, DrawImage, DrawImagePoints, SerializableObject
        ].to_h { |klass| [klass::TYPE, klass] }.freeze
      end

      def decode(frame)
        registry.fetch(frame.type, Unknown).new(frame)
      end

      def decode_all(frames)
        frames.map { |frame| decode(frame) }
      end
    end
  end
end
