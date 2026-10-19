# frozen_string_literal: true

require_relative "wmf_geometry"

module WmfPointArraysSupport
  include WmfGeometrySupport

  def point_array_record(function, counts, coordinates)
    payload = counts.pack("v*") + coordinates.flatten.pack("s<*")
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end

  def point_array_class(function)
    Emf::Model::Wmf::Records.const_get({ 0x24 => :Polygon, 0x25 => :Polyline, 0x38 => :PolyPolygon }.fetch(function & 0xFF))
  end

  def point_array_points(coordinates)
    coordinates.map { |x, y| Emf::Model::Wmf::Records::PointS.new(x: x, y: y) }
  end
end
