# frozen_string_literal: true

module ExtendedPenRecords
  def extended_pen_record(styles: [0, 0xFFFFFFFF, 7], info: "INFO", bits: "BITS", bits_first: false)
    fixed = 52 + (styles.length * 4)
    offsets = { info: 0, bits: 0 }
    buffers = "".b
    order = bits_first ? %i[bits info] : %i[info bits]
    order.each do |kind|
      data = kind == :info ? info : bits
      next if data.nil?

      buffers << "GAP!" << ("\0" * ((4 - ((fixed + buffers.bytesize + 4) % 4)) % 4))
      offsets[kind] = fixed + buffers.bytesize
      buffers << data
    end
    size = fixed + buffers.bytesize + 4
    fields = [95, size, 0x80000001, offsets[:info], info.to_s.bytesize, offsets[:bits], bits.to_s.bytesize,
              0xFFFFFFFF, 0x80000000, 0xFFFFFFFE, 0xFEDCBA98, 0xFFFFFFFF, styles.length, *styles].pack("V*")
    "#{fields}#{buffers}TAIL"
  end
end
