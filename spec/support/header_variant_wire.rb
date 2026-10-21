# frozen_string_literal: true

# Raw EMR_HEADER builder for variant specs: every field is a plain integer so
# malformed layouts (lying counts, wild offsets) can be written byte for byte.
module HeaderVariantWire
  DEFAULTS = {
    bounds: [-5, 6, 70_000, -80_000], frame: [1, -2, 300, 400],
    signature: 0x464D4520, version: 0x00010000, n_bytes: 0, n_records: 2, n_handles: 1,
    reserved: 0, n_description: 0, off_description: 0, n_pal_entries: 0,
    device: [640, -480], millimeters: [320, 240], cb_pixel_format: 0, off_pixel_format: 0,
    b_open_gl: 0, micrometers: [-1, 2]
  }.freeze

  FOLLOWING = [17, 12, 7].pack("V3")
  EOF_RECORD = [14, 20, 0, 0, 20].pack("V5")

  module_function

  # Header of exactly +size+ bytes: fixed fields truncated or padded with 0xEE.
  def header(size, type: 1, declared_size: size, **overrides)
    values = DEFAULTS.merge(overrides)
    head = [type, declared_size, *values[:bounds], *values[:frame], values[:signature],
            values[:version], values[:n_bytes], values[:n_records]].pack("l<2l<8V4")
    head << [values[:n_handles], values[:reserved]].pack("v2")
    head << [values[:n_description], values[:off_description], values[:n_pal_entries]].pack("V3")
    head << [*values[:device], *values[:millimeters]].pack("l<4")
    head << [values[:cb_pixel_format], values[:off_pixel_format], values[:b_open_gl]].pack("V3")
    head << values[:micrometers].pack("l<2")
    (head + ("\xEE".b * [size - head.bytesize, 0].max)).byteslice(0, size)
  end

  def stream(size, **overrides)
    header(size, **overrides) + FOLLOWING + EOF_RECORD
  end
end
