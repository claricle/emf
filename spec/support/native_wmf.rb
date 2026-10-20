# frozen_string_literal: true

module NativeWmfSupport
  def native_wmf_bytes(records, capacity: 2, placeable: false, trailing: "tail".b)
    eof = [3, 0].pack("Vv")
    records = [*records, eof]
    header = [2, 9, 0x300, 9 + records.sum { |record| record.bytesize / 2 }, capacity,
              records.map { |record| record.bytesize / 2 }.max, 7].pack("v3VvVv")
    prefix = "".b
    if placeable
      prefix = [Emf::Wmf::Binary::PLACEABLE_KEY, 0, -5, -6, 50, 60, 1440, 0].pack("Vvs<4vV")
      prefix += [Emf::Wmf::Binary.checksum(prefix)].pack("v")
    end
    prefix + header + records.join + trailing
  end

  def native_wmf_record(function, payload)
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end
end
