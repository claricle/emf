# frozen_string_literal: true

module Emf
  module Emr
    # The lazy source of a fixed-layout or point-array record that is only its
    # bytes: a WireAdapter over it holds the frozen input and the record's
    # span, and makes no BinData wire until `#wire` is asked for. `#values`
    # reads the bytes directly. Materialising reads the span with the same
    # FastFill the eager parse uses, so the wire is the one a parse makes.
    class FilledRecord
      # The source for the record at `offset` of the frozen binary `data`,
      # or nil when it needs the eager parse: no fixed-layout filler, a span
      # shorter than the layout, a point count past the span, or a header
      # disagreeing with the span. The caller has checked the span against
      # `data`.
      def self.for(type_id, offset, length, data)
        filler = Binary::FastFill.for(type_id) || Binary::FastFill.for_points(type_id)
        return unless filler && length >= filler.size && filler.fits?(data, offset, length)

        new(filler, data, offset, length, type_id)
      end

      def initialize(filler, data, offset, length, type_id)
        @filler = filler
        @data = data
        @offset = offset
        @length = length
        @type_id = type_id
      end

      attr_reader :length

      # The Ruby parser has always answered a BinData Uint32le here (the wire's
      # i_type), so a byte-backed record keeps that type.
      def type_id
        BinData::Uint32le.new(@type_id)
      end

      def to_binary_s
        @data.byteslice(@offset, @length)
      end

      def wire_class
        @filler.wire_class
      end

      # [frozen binary data, record offset, untouched]: the bytes the wire is
      # filled from, and no wire exists yet.
      def value_source
        [@data, @offset, true]
      end

      def materialize
        wire, @suffix = @filler.call_at(@data, @offset, @length)
        raise FormatError, "record disagrees with its bytes" unless wire

        wire
      end

      def suffix(_wire)
        @suffix
      end
    end
  end
end
