# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_state"

RSpec.describe "Native record variants: state, transform and path control" do
  it_behaves_like "record variants", %w[
    SetBkMode SetMapMode SetRop2 SetPolyFillMode SetStretchBltMode SetTextAlign SetArcDirection SetIcmMode
    SetLayout SetMapperFlags SelectObject DeleteObject RestoreDc SetMiterLimit SetTextColor SetBkColor
    SaveDc BeginPath EndPath CloseFigure FlattenPath WidenPath AbortPath SetMetArgn
    SetWindowOrgEx SetViewportOrgEx SetBrushOrgEx MoveToEx LineTo OffsetClipRgn SetWindowExtEx SetViewportExtEx
    SetPixelV Rectangle Ellipse RoundRect Arc ArcTo Chord Pie AngleArc ExcludeClipRect IntersectClipRect
    ScaleViewportExtEx ScaleWindowExtEx SetWorldTransform ModifyWorldTransform CreatePen CreateBrushIndirect
  ]
end
