# frozen_string_literal: true

# Ensure the shared bindata primitives (rectl, point_l, color_ref, etc.) are
# registered before any record class is parsed. Referencing the constant
# triggers autoload of emf/binary/types, which calls
# BinData::RegisteredClasses.register for each primitive.

module Emf
  module Emr
    module Binary
      module Records
        autoload :Raw, "emf/emr/binary/records/raw"
        autoload :Eof, "emf/emr/binary/records/eof"
        autoload :SetTextColor, "emf/emr/binary/records/set_text_color"
        autoload :SetBkColor, "emf/emr/binary/records/set_bk_color"
        autoload :SetBkMode, "emf/emr/binary/records/set_bk_mode"
        autoload :SetMapMode, "emf/emr/binary/records/set_map_mode"
        autoload :SetRop2, "emf/emr/binary/records/set_rop2"
        autoload :SetPolyFillMode, "emf/emr/binary/records/set_poly_fill_mode"
        autoload :SetTextAlign, "emf/emr/binary/records/set_text_align"
        autoload :SetStretchBltMode, "emf/emr/binary/records/set_stretch_blt_mode"
        autoload :SaveDc, "emf/emr/binary/records/save_dc"
        autoload :RestoreDc, "emf/emr/binary/records/restore_dc"
        autoload :SelectObject, "emf/emr/binary/records/select_object"
        autoload :DeleteObject, "emf/emr/binary/records/delete_object"
        autoload :CreatePen, "emf/emr/binary/records/create_pen"
        autoload :CreateBrushIndirect, "emf/emr/binary/records/create_brush_indirect"
        autoload :SetWindowOrgEx, "emf/emr/binary/records/set_window_org_ex"
        autoload :SetWindowExtEx, "emf/emr/binary/records/set_window_ext_ex"
        autoload :SetViewportOrgEx, "emf/emr/binary/records/set_viewport_org_ex"
        autoload :SetViewportExtEx, "emf/emr/binary/records/set_viewport_ext_ex"
        autoload :MoveToEx, "emf/emr/binary/records/move_to_ex"
        autoload :LineTo, "emf/emr/binary/records/line_to"
        autoload :Rectangle, "emf/emr/binary/records/rectangle"
        autoload :Ellipse, "emf/emr/binary/records/ellipse"
        autoload :RoundRect, "emf/emr/binary/records/round_rect"
        autoload :Arc, "emf/emr/binary/records/arc"
        autoload :ArcTo, "emf/emr/binary/records/arc_to"
        autoload :Chord, "emf/emr/binary/records/chord"
        autoload :Pie, "emf/emr/binary/records/pie"
        autoload :Polygon, "emf/emr/binary/records/polygon"
        autoload :Polyline, "emf/emr/binary/records/polyline"
        autoload :PolyBezier, "emf/emr/binary/records/poly_bezier"
        autoload :Polygon16, "emf/emr/binary/records/polygon16"
        autoload :Polyline16, "emf/emr/binary/records/polyline16"
        autoload :PolyBezier16, "emf/emr/binary/records/poly_bezier16"
        autoload :PolyBezierTo, "emf/emr/binary/records/poly_bezier_to"
        autoload :PolyBezierTo16, "emf/emr/binary/records/poly_bezier_to16"
        autoload :PolylineTo, "emf/emr/binary/records/polyline_to"
        autoload :PolylineTo16, "emf/emr/binary/records/polyline_to16"
        autoload :PolyPolyline, "emf/emr/binary/records/poly_polyline"
        autoload :PolyPolygon, "emf/emr/binary/records/poly_polygon"
        autoload :PolyPolyline16, "emf/emr/binary/records/poly_polyline16"
        autoload :PolyPolygon16, "emf/emr/binary/records/poly_polygon16"
        autoload :Comment, "emf/emr/binary/records/comment"
        autoload :SetWorldTransform, "emf/emr/binary/records/set_world_transform"
        autoload :ModifyWorldTransform, "emf/emr/binary/records/modify_world_transform"
        autoload :BeginPath, "emf/emr/binary/records/begin_path"
        autoload :EndPath, "emf/emr/binary/records/end_path"
        autoload :CloseFigure, "emf/emr/binary/records/close_figure"
        autoload :FillPath, "emf/emr/binary/records/fill_path"
        autoload :StrokePath, "emf/emr/binary/records/stroke_path"
        autoload :StrokeAndFillPath, "emf/emr/binary/records/stroke_and_fill_path"
        autoload :FlattenPath, "emf/emr/binary/records/flatten_path"
        autoload :WidenPath, "emf/emr/binary/records/widen_path"
        autoload :SelectClipPath, "emf/emr/binary/records/select_clip_path"
        autoload :AbortPath, "emf/emr/binary/records/abort_path"
        autoload :SetMiterLimit, "emf/emr/binary/records/set_miter_limit"
        autoload :ExtTextOutW, "emf/emr/binary/records/ext_text_out_w"
        autoload :ExtTextOutA, "emf/emr/binary/records/ext_text_out_a"
        autoload :CreateFontIndirectW, "emf/emr/binary/records/create_font_indirect_w"
        autoload :ExtCreatePen, "emf/emr/binary/records/ext_create_pen"
        autoload :StretchDIBits, "emf/emr/binary/records/stretch_dibits"

        # Maps EMR_* integer type codes to wire class names. Adding a record:
        # 1. Add a wire class file under records/.
        # 2. Add an autoload line above.
        # 3. Add an entry here.
        TYPE_TO_NAME = {
          Binary::TypeCodes::EOF => :Eof,
          Binary::TypeCodes::SETTEXTCOLOR => :SetTextColor,
          Binary::TypeCodes::SETBKCOLOR => :SetBkColor,
          Binary::TypeCodes::SETBKMODE => :SetBkMode,
          Binary::TypeCodes::SETMAPMODE => :SetMapMode,
          Binary::TypeCodes::SETROP2 => :SetRop2,
          Binary::TypeCodes::SETPOLYFILLMODE => :SetPolyFillMode,
          Binary::TypeCodes::SETTEXTALIGN => :SetTextAlign,
          Binary::TypeCodes::SETSTRETCHBLTMODE => :SetStretchBltMode,
          Binary::TypeCodes::SAVEDC => :SaveDc,
          Binary::TypeCodes::RESTOREDC => :RestoreDc,
          Binary::TypeCodes::SELECTOBJECT => :SelectObject,
          Binary::TypeCodes::DELETEOBJECT => :DeleteObject,
          Binary::TypeCodes::CREATEPEN => :CreatePen,
          Binary::TypeCodes::CREATEBRUSHINDIRECT => :CreateBrushIndirect,
          Binary::TypeCodes::SETWINDOWORGEX => :SetWindowOrgEx,
          Binary::TypeCodes::SETWINDOWEXTEX => :SetWindowExtEx,
          Binary::TypeCodes::SETVIEWPORTORGEX => :SetViewportOrgEx,
          Binary::TypeCodes::SETVIEWPORTEXTEX => :SetViewportExtEx,
          Binary::TypeCodes::MOVETOEX => :MoveToEx,
          Binary::TypeCodes::LINETO => :LineTo,
          Binary::TypeCodes::RECTANGLE => :Rectangle,
          Binary::TypeCodes::ELLIPSE => :Ellipse,
          Binary::TypeCodes::ROUNDRECT => :RoundRect,
          Binary::TypeCodes::ARC => :Arc,
          Binary::TypeCodes::ARCTO => :ArcTo,
          Binary::TypeCodes::CHORD => :Chord,
          Binary::TypeCodes::PIE => :Pie,
          Binary::TypeCodes::POLYGON => :Polygon,
          Binary::TypeCodes::POLYLINE => :Polyline,
          Binary::TypeCodes::POLYBEZIER => :PolyBezier,
          Binary::TypeCodes::POLYGON16 => :Polygon16,
          Binary::TypeCodes::POLYLINE16 => :Polyline16,
          Binary::TypeCodes::POLYBEZIER16 => :PolyBezier16,
          Binary::TypeCodes::POLYBEZIERTO => :PolyBezierTo,
          Binary::TypeCodes::POLYBEZIERTO16 => :PolyBezierTo16,
          Binary::TypeCodes::POLYLINETO => :PolylineTo,
          Binary::TypeCodes::POLYLINETO16 => :PolylineTo16,
          Binary::TypeCodes::POLYPOLYLINE => :PolyPolyline,
          Binary::TypeCodes::POLYPOLYGON => :PolyPolygon,
          Binary::TypeCodes::POLYPOLYLINE16 => :PolyPolyline16,
          Binary::TypeCodes::POLYPOLYGON16 => :PolyPolygon16,
          Binary::TypeCodes::COMMENT => :Comment,
          Binary::TypeCodes::SETWORLDTRANSFORM => :SetWorldTransform,
          Binary::TypeCodes::MODIFYWORLDTRANSFORM => :ModifyWorldTransform,
          Binary::TypeCodes::BEGINPATH => :BeginPath,
          Binary::TypeCodes::ENDPATH => :EndPath,
          Binary::TypeCodes::CLOSEFIGURE => :CloseFigure,
          Binary::TypeCodes::FILLPATH => :FillPath,
          Binary::TypeCodes::STROKEPATH => :StrokePath,
          Binary::TypeCodes::STROKEANDFILLPATH => :StrokeAndFillPath,
          Binary::TypeCodes::FLATTENPATH => :FlattenPath,
          Binary::TypeCodes::WIDENPATH => :WidenPath,
          Binary::TypeCodes::SELECTCLIPPATH => :SelectClipPath,
          Binary::TypeCodes::ABORTPATH => :AbortPath,
          Binary::TypeCodes::SETMITERLIMIT => :SetMiterLimit,
          Binary::TypeCodes::EXTTEXTOUTW => :ExtTextOutW,
          Binary::TypeCodes::EXTTEXTOUTA => :ExtTextOutA,
          Binary::TypeCodes::EXTCREATEFONTINDIRECTW => :CreateFontIndirectW,
          Binary::TypeCodes::EXTCREATEPEN => :ExtCreatePen,
          Binary::TypeCodes::STRETCHDIBITS => :StretchDIBits
        }.freeze

        def self.lookup(type_id)
          name = TYPE_TO_NAME[type_id]
          name ? const_get(name) : Raw
        end
      end
    end
  end
end
