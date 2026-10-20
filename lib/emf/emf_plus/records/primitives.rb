# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # Shared EMF+ structures (MS-EMFPLUS 2.2.2). Record files require the ones
      # they use; the autoloads let callers reach any of them directly.
      module Primitives
        autoload :ARGB, "emf/emf_plus/records/primitives/argb"
        autoload :Bitmap, "emf/emf_plus/records/primitives/bitmap"
        autoload :BitmapData, "emf/emf_plus/records/primitives/bitmap_data"
        autoload :BlendColors, "emf/emf_plus/records/primitives/blend_colors"
        autoload :BlendFactors, "emf/emf_plus/records/primitives/blend_factors"
        autoload :ByteReader, "emf/emf_plus/records/primitives/byte_reader"
        autoload :CharacterRange, "emf/emf_plus/records/primitives/character_range"
        autoload :CompressedImage, "emf/emf_plus/records/primitives/compressed_image"
        autoload :FocusScaleData, "emf/emf_plus/records/primitives/focus_scale_data"
        autoload :GraphicsVersion, "emf/emf_plus/records/primitives/graphics_version"
        autoload :LanguageIdentifier, "emf/emf_plus/records/primitives/language_identifier"
        autoload :Metafile, "emf/emf_plus/records/primitives/metafile"
        autoload :Palette, "emf/emf_plus/records/primitives/palette"
        autoload :Path, "emf/emf_plus/records/primitives/path"
        autoload :PathPointType, "emf/emf_plus/records/primitives/path_point_type"
        autoload :PathPointTypeRLE, "emf/emf_plus/records/primitives/path_point_type_rle"
        autoload :Point, "emf/emf_plus/records/primitives/point"
        autoload :PointArray, "emf/emf_plus/records/primitives/point_array"
        autoload :PointF, "emf/emf_plus/records/primitives/point_f"
        autoload :PointR, "emf/emf_plus/records/primitives/point_r"
        autoload :Rect, "emf/emf_plus/records/primitives/rect"
        autoload :RectArray, "emf/emf_plus/records/primitives/rect_array"
        autoload :RectF, "emf/emf_plus/records/primitives/rect_f"
        autoload :RegionNode, "emf/emf_plus/records/primitives/region_node"
        autoload :RegionNodeChildNodes, "emf/emf_plus/records/primitives/region_node_child_nodes"
        autoload :RegionNodePath, "emf/emf_plus/records/primitives/region_node_path"
        autoload :RelativeCoordinate, "emf/emf_plus/records/primitives/relative_coordinate"
        autoload :StringFormatData, "emf/emf_plus/records/primitives/string_format_data"
        autoload :TransformMatrix, "emf/emf_plus/records/primitives/transform_matrix"
      end
    end
  end
end
