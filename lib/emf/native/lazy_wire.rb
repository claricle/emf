# frozen_string_literal: true

module Emf
  module Native
    # Owns validated Ruby values, never a native document or its hydrator.
    class LazyWire
      def initialize(klass, fields, bytes, record)
        @klass = klass
        @fields = fields.merge(i_type: record.fetch(:type), n_size: bytes.bytesize)
        @bytes = bytes
        @text_payload = record.fetch(:payload) if [74, 75].include?(record.fetch(:family))
      end

      def type_id
        @fields.fetch(:i_type)
      end

      def to_binary_s
        @bytes
      end

      def materialize
        wire = @klass.new(**@fields)
        Fields.preserve_text_scales(wire, @text_payload) if @text_payload
        wire
      end
    end
  end
end
