# frozen_string_literal: true

module Emf
  module Model
    module Geometry
      autoload :Point, "emf/model/geometry/point"
      autoload :PointF, "emf/model/geometry/point_f"
      autoload :PointS, "emf/model/geometry/point_s"
      autoload :Size, "emf/model/geometry/size"
      autoload :Rect, "emf/model/geometry/rect"
      autoload :RectS, "emf/model/geometry/rect_s"
      autoload :Color, "emf/model/geometry/color"
      autoload :Matrix, "emf/model/geometry/matrix"
    end
  end
end
