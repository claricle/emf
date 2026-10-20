# frozen_string_literal: true

module PaletteRecords
  def palette_record(kind, entries: [[1, 2, 255, 128], [254, 3, 0, 255]])
    colors = entries.flatten.pack("C*")
    payload = case kind
              when 48 then [0x8000000F].pack("V")
              when 49 then [0x87654321].pack("V") + [0xFEDC, entries.length].pack("v2") + colors
              when 50 then [0x87654321, 0xFFFFFFFF, entries.length].pack("V3") + colors
              when 51 then [0x87654321, 0xFFFFFFFF].pack("V2")
              when 52 then "".b
              end
    "#{[kind, 12 + payload.bytesize].pack('V2')}#{payload}TAIL"
  end

  def palette_snapshot(payload, family, raw)
    envelope = [0, 108, raw.bytesize, family - 34, family, payload.bytesize].pack("Q<3V2Q<")
    body = [108, 1, 0, 0, 0].pack("Q<5") + ("\0" * 112) + ("\0" * 108) + envelope + payload
    Emf::Native::Snapshot.new("EMFS#{[2, 16 + body.bytesize].pack('VQ<')}#{body}")
  end
end
