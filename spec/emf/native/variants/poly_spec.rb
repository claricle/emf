# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_poly"

RSpec.describe "Native record variants: point and polygon records" do
  it_behaves_like "record variants", %w[
    Polygon Polyline PolyBezier PolyBezierTo PolylineTo Polygon16 Polyline16 PolyBezier16 PolyBezierTo16
    PolylineTo16 PolyDraw PolyDraw16 PolyPolygon PolyPolyline PolyPolygon16 PolyPolyline16
  ]
end
