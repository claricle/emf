# frozen_string_literal: true

require_relative "native_wmf"

# Crafted WMF files whose header Size or MaxRecord disagrees with the record stream.
module WmfHeaderDrift
  include NativeWmfSupport

  SIZE_OFFSET = 6
  MAX_RECORD_OFFSET = 12

  # name => [field offset in the standard header, declared words]; the pristine file has Size 9 + 7 + 5 + 3 = 24 and
  # MaxRecord 7.
  CASES = {
    "Size too large" => [SIZE_OFFSET, 24 + 500],
    "Size too small" => [SIZE_OFFSET, 12],
    "Size zero" => [SIZE_OFFSET, 0],
    "MaxRecord too small" => [MAX_RECORD_OFFSET, 3],
    "MaxRecord too large" => [MAX_RECORD_OFFSET, 900],
    "MaxRecord zero" => [MAX_RECORD_OFFSET, 0]
  }.freeze

  def pristine(placeable: false, trailing: "".b)
    records = [native_wmf_record(0x041B, [1, 2, 3, 4].pack("s<4")), native_wmf_record(0x0214, [5, 6].pack("s<2"))]
    native_wmf_bytes(records, placeable: placeable, trailing: trailing)
  end

  def drifted(bytes, offset, value, placeable: false)
    copy = bytes.dup
    copy[(placeable ? 22 : 0) + offset, 4] = [value].pack("V")
    copy
  end

  # [check, header offset, declared, actual] expected on Metafile#errors for the case.
  def expected_evidence(offset, value)
    offset == SIZE_OFFSET ? [:header_file_size_invalid, offset, value, 24] : [:max_record_mismatch, offset, value, 7]
  end
end
