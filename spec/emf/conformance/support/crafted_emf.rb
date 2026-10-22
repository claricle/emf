# frozen_string_literal: true

module Emf
  module SpecSupport
    # Builds a minimal valid EMF (88-byte header + EMR_EOF) and lets a spec
    # change one thing at a time. Offsets: nBytes 48, nRecords 52, nHandles 56,
    # nDescription 64, offDescription 68.
    module CraftedEmf
      module_function

      HEADER_SIZE = 88
      EOF_RECORD = [14, 20, 0, 16, 20].pack("V5").freeze

      def header(n_bytes:, n_records:, n_handles: 1, size: HEADER_SIZE, n_description: 0, off_description: 0, signature: 0x464D4520)
        fixed = [1, size].pack("V2") + ([0, 0, 99, 99] + [0, 0, 99, 99]).pack("l<8") +
                [signature, 0x10000, n_bytes, n_records].pack("V4") + [n_handles, 0].pack("v2") +
                [n_description, off_description, 0, 1, 1, 1, 1].pack("V7")
        fixed.ljust(size, "\0".b)
      end

      # Raw record bytes: type, declared size (defaults to the real size), body.
      def record(type, body = "".b, size: nil)
        total = 8 + body.bytesize
        [type, size || total].pack("V2") + body
      end

      # records: raw record byte strings placed between the header and the EOF record.
      def build(records: [], eof: EOF_RECORD, count: nil, bytes: nil, **header_options)
        body = records.join + eof
        total = HEADER_SIZE + body.bytesize
        count ||= records.size + 2
        header(n_bytes: bytes || total, n_records: count, **header_options) + body
      end
    end
  end
end
