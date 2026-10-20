# frozen_string_literal: true

require_relative "native_wmf"

module WmfDcEscapeValidationSupport
  include NativeWmfSupport

  def serialize_dc_escape_record(record)
    metafile = Emf.parse(native_wmf_bytes([]))
    edited = Emf::Model::Metafile.new(format: :wmf, header: metafile.header, records: [record, *metafile.records])
    Emf.serialize(edited)
  end
end
