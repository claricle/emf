# frozen_string_literal: true

require_relative "wmf_geometry"

module WmfObjectsSupport
  include WmfGeometrySupport

  def object_record(function, payload)
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end

  def object_file(records, capacity: 2, placeable: false, trailing: "".b)
    bytes = geometry_file(records, placeable: placeable, trailing: trailing)
    bytes[(placeable ? 22 : 0) + 10, 2] = [capacity].pack("v")
    bytes
  end
end
