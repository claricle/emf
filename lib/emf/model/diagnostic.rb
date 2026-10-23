# frozen_string_literal: true

module Emf
  module Model
    class Diagnostic
      TYPE_NAMES = Emf::Emr::Binary::TypeCodes.constants.to_h do |name|
        [Emf::Emr::Binary::TypeCodes.const_get(name), "EMR_#{name}".freeze]
      end.freeze

      attr_reader :record_index, :record_code, :record_type, :byte_offset, :disposition

      def initialize(record_index:, record_code:, byte_offset:, disposition:)
        raise ArgumentError, "invalid diagnostic disposition" unless %i[skipped preserved_raw].include?(disposition)
        unless [record_index, record_code, byte_offset].all? { |value| value.is_a?(Integer) && value >= 0 }
          raise ArgumentError, "diagnostic positions and code must be nonnegative integers"
        end

        @record_index = record_index
        @record_code = record_code
        @record_type = TYPE_NAMES.fetch(record_code) { format("UNKNOWN(0x%08X)", record_code).freeze }
        @byte_offset = byte_offset
        @disposition = disposition
        freeze
      end

      def to_h
        { record_index: record_index, record_code: record_code, record_type: record_type,
          byte_offset: byte_offset, disposition: disposition }
      end

      def ==(other)
        other.is_a?(self.class) && to_h == other.to_h
      end
      alias eql? ==

      def hash
        to_h.hash
      end
    end
  end
end
