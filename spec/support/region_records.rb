# frozen_string_literal: true

module RegionRecords
  def region_record(type, rectangles: [[-0x80000000, 2, 0x7FFFFFFF, -4]], extra: "IN!!", suffix: "OUT!")
    rect_bytes = rectangles.flatten.pack("l<*")
    data = [32, 0xFFFFFFFF, rectangles.length, rect_bytes.bytesize].pack("V4") +
           [-9, 10, 11, -12].pack("l<4") + rect_bytes + extra
    fixed = if type == 75
              [data.bytesize, 0xFFFFFFFF].pack("V2")
            else
              [-1, -2, 3, 4].pack("l<4") + [data.bytesize].pack("V") +
                ([71, 72].include?(type) ? [0x80000001].pack("V") : "") +
                (type == 72 ? [-13, 14].pack("l<2") : "")
            end
    [type, 8 + fixed.bytesize + data.bytesize + suffix.bytesize].pack("V2") + fixed + data + suffix
  end
end
