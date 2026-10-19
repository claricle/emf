# frozen_string_literal: true

module WmfGeometrySupport
  def geometry_with_records(metafile, records)
    Emf::Model::Metafile.new(format: :wmf, header: metafile.header, records: records, trailing: metafile.trailing)
  end

  def geometry_record(function, values)
    [3 + values.length, function, *values].pack("Vvs<*")
  end

  def geometry_file(records, placeable: false, trailing: "".b)
    records += [[3, 0].pack("Vv")]
    words = records.map { |record| record.bytesize / 2 }
    header = [2, 9, 0x300, 9 + words.sum, 11, words.max, 7].pack("v3VvVv")
    prefix = "".b
    if placeable
      prefix = [0x9AC6CDD7, 0, -100, -200, 300, 400, 1440, 0].pack("Vvs<4vV")
      prefix += [prefix.unpack("v10").reduce(0, :^)].pack("v")
    end
    prefix + header + records.join + trailing
  end
end
