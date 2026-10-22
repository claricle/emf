# frozen_string_literal: true

module Emf
  module Conformance
    # What a rule sees: the parsed model plus the input length. `format` is the
    # Metafile format, or :unparseable when the parser rejected the input
    # (then `metafile` is nil and `parse_failure` holds the exception).
    class Context
      attr_reader :metafile, :bytes, :parse_failure

      def initialize(metafile: nil, bytes: nil, parse_failure: nil)
        @metafile = metafile
        @bytes = bytes
        @parse_failure = parse_failure
      end

      def format = metafile ? metafile.format : :unparseable

      def header = metafile.header

      def records = metafile.records

      # Input length in bytes, or nil when the metafile was passed in without its bytes.
      def byte_length = bytes&.bytesize

      # Declared EMR size of a record (its nSize field).
      # EMF record size in bytes; nil for records without an EMF wire (WMF).
      def record_size(record) = (record.wire.n_size.to_i if record.respond_to?(:wire))

      def record_type(record) = record.type_id.to_i

      # Total number of EMF records the header counts, header included.
      def record_count = records.size + 1
    end
  end
end
