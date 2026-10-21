# frozen_string_literal: true

require "stringio"

module Emf
  module Native
    # Turns native snapshot diagnostics into the Ruby parser's ParseErrors.
    #
    # Framing diagnostics (kinds 1-3) carry their numbers, so the Ruby message
    # is rebuilt from them. A kind-4 diagnostic only says that native could not
    # decode a record's payload, not why, and native decodes some bodies Ruby
    # keeps opaque. The Ruby parser is the contract for such a record, so its own
    # per-record reader decides: it accepts the record as typed, or preserves it as
    # Raw with its own message. Record bodies native hydrates as opaque classes are
    # never rejected by Ruby, so their diagnostic is dropped without a Ruby read.
    class Diagnostics
      INVALID_PAYLOAD = 4
      Recovery = Struct.new(:adapter, :errors, :wire)

      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
        @recovered = invalid_payload_offsets.to_h { |offset, type| [offset, recover(offset, type)] }
      end

      def recovered?(offset)
        @recovered.key?(offset)
      end

      def adapter_at(offset)
        @recovered[offset]&.adapter
      end

      def emf_plus_at(offset)
        wire = @recovered.fetch(offset).wire
        Emr::Parser.extract_emf_plus(wire) if wire.is_a?(Emr::Binary::Records::Comment)
      end

      def errors
        @snapshot.diagnostics.flat_map do |kind, has_type, type, reserved, offset, detail1, detail2|
          raise FormatError, "invalid native snapshot diagnostic" unless (1..4).cover?(kind) && (0..1).cover?(has_type) && reserved.zero?
          next @recovered.fetch(offset).errors if kind == INVALID_PAYLOAD

          [ParseError.new(offset: offset, record_code: has_type == 1 ? type : nil, message: message(kind, offset, detail1, detail2))]
        end
      end

      private

      def invalid_payload_offsets
        @snapshot.diagnostics.filter_map do |kind, has_type, type, _reserved, offset|
          [offset, has_type == 1 ? type : nil] if kind == INVALID_PAYLOAD
        end
      end

      def recover(offset, type)
        return Recovery.new(nil, [], nil) if Hydrator::OPAQUE_BODY_TYPES.include?(type)

        errors = []
        io = StringIO.new(@input)
        io.pos = offset
        wire, suffix = Emr::Parser.read_record(io, offset, errors)
        adapter = Model::Emr::Records::WireAdapter.new(wire: wire, offset: offset, suffix: suffix) if wire
        Recovery.new(adapter, errors, wire)
      end

      def message(kind, offset, detail1, detail2)
        case kind
        when 1 then "truncated record header at offset #{offset} (#{detail1} bytes)"
        when 2 then "record nSize #{detail1} < 8 bytes (offset #{offset})"
        when 3 then "truncated record at offset #{offset} (claimed #{detail1}, got #{detail2 - 8})"
        else "native parse diagnostic #{kind} at offset #{offset} (#{detail1}, #{detail2})"
        end
      end
    end
  end
end
