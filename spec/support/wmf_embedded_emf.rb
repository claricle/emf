# frozen_string_literal: true

require_relative "native_wmf"

module WmfEmbeddedEmfSupport
  include NativeWmfSupport

  # Raw data of one 0x000F escape. Overrides replace individual metadata fields.
  def embedded_segment_data(chunk, count:, total:, remaining:, checksum: 0, **overrides)
    meta = { identifier: 0x43464D57, type: 1, version: 0x00010000, checksum: checksum, flags: 0, count: count,
             current: chunk.bytesize, remaining: remaining, total: total }.merge(overrides)
    meta.values_at(:identifier, :type, :version).pack("V3") + [meta[:checksum]].pack("v") +
      meta.values_at(:flags, :count, :current, :remaining, :total).pack("V5") + chunk
  end

  def embedded_escape(data, padding: nil)
    padding = 0 if padding.nil? && data.bytesize.odd?
    Emf::Model::Wmf::Records::Escape.new(escape_function: 0x000F, data: data, padding: padding)
  end

  def embedded_escapes(stream, size)
    checksum = Emf::Wmf::EmbeddedEmf.checksum(stream)
    chunks = stream.b.chars.each_slice(size).map(&:join)
    left = stream.bytesize
    chunks.map do |chunk|
      left -= chunk.bytesize
      embedded_escape(embedded_segment_data(chunk, count: chunks.size, total: stream.bytesize, remaining: left,
                                                   checksum: checksum))
    end
  end

  def wire_escape(record)
    native_wmf_escape(record.escape_function, record.data, padding: record.padding&.chr&.b || "".b)
  end
end
