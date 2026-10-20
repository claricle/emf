# frozen_string_literal: true

module WmfGeometryRemainingSupport
  def remaining_geometry_record(function, fields, format, suffix = "".b)
    payload = fields.values.pack(format) + suffix
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end

  def remaining_geometry_metafile(record)
    geometry_with_records(Emf.parse(geometry_file([])), [record, Emf::Model::Wmf::Records::Eof.new])
  end
end
