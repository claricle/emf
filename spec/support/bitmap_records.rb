# frozen_string_literal: true

module BitmapRecords
  def bitmap_record(type, layout: :reversed)
    fixed, source, mask = Emf::Native::BitmapFields::LAYOUTS.values.find { |entry| entry.first == type }.drop(1)
    bytes = Array.new(fixed / 4) { |i| 0xFFFFFF00 + i }.pack("V*")
    bytes[0, 8] = [type, fixed].pack("V2")
    pointers = [source, source + 8, mask, mask && (mask + 8)]
    zero_pointer = [0, 0].pack("V2")
    pointers.compact.each { |offset| bytes[offset, 8] = zero_pointer }
    if layout != :absent
      order = mask ? [3, 1, 2, 0] : [1, 0]
      order.each_with_index do |index, n|
        bytes << (n.zero? ? "gap" : "?")
        data = layout == :empty ? "" : "buf#{index}"
        bytes[pointers.fetch(index), 8] = [bytes.bytesize, data.bytesize].pack("V2")
        bytes << data
      end
    end
    bytes << "TAIL"
    bytes << "\x00" until (bytes.bytesize % 4).zero?
    bytes[4, 4] = [bytes.bytesize].pack("V")
    bytes
  end
end
