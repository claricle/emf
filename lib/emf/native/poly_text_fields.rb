# frozen_string_literal: true

module Emf
  module Native
    # Snapshot families 104/105 encode a 36-byte header and 52-byte entry
    # headers followed by text units and Dx words. Family 106 is twelve words.
    # Source gaps and suffixes remain authoritative for the public body API.
    module PolyTextFields
      def self.call(payload, family, raw, type)
        expected_type = { 104 => 96, 105 => 97, 106 => 23 }.fetch(family)
        valid_header = type == expected_type && raw.bytesize >= 8 && raw.unpack1("V") == type
        reject! unless valid_header && raw.byteslice(4, 4).unpack1("V") == raw.bytesize

        if family == 106
          reject! unless payload.bytesize == 24 && raw.bytesize >= 32 && payload == raw.byteslice(8, 24)
        else
          TextValidator.new(payload, raw, family == 104 ? 1 : 2).call
        end
        [Emr::Binary::Records.lookup(type), { body: raw.byteslice(8..) }]
      end

      def self.reject!
        raise FormatError, "invalid native PolyTextOut/COLORADJUSTMENT payload"
      end

      # The source descriptor table is variable width. Validate every semantic
      # field and detached span before constructing the public body-backed wire.
      class TextValidator
        def initialize(payload, raw, width)
          @payload = payload
          @raw = raw
          @width = width
          @cursor = 36
          @descriptor = 40
          @spans = []
        end

        def call
          count.times { entry }
          reject! unless @cursor == @payload.bytesize

          finish = @descriptor
          @spans.sort.each do |start, stop|
            reject! if start < finish
            finish = stop
          end
        end

        private

        def count
          reject! unless @payload.bytesize >= 36 && @raw.bytesize >= 40
          reject! unless @payload.byteslice(0, 28) == @raw.byteslice(8, 28)

          value = @payload.byteslice(28, 8).unpack1("Q<")
          reject! unless value == @raw.byteslice(36, 4).unpack1("V")
          reject! unless value <= (@payload.bytesize - 36) / 52 && value <= (@raw.bytesize - 40) / 24
          value
        end

        def entry
          reject! unless @cursor + 52 <= @payload.bytesize && @descriptor + 24 <= @raw.bytesize

          options, has_rect = @payload.byteslice(@cursor + 8, 8).unpack("V2")
          size = rectangle(options, has_rect)
          reject! unless @payload.byteslice(@cursor, 8) == @raw.byteslice(@descriptor, 8)
          reject! unless options == @raw.byteslice(@descriptor + 16, 4).unpack1("V")

          chars, string = @raw.byteslice(@descriptor + 8, 8).unpack("V2")
          dx = @raw.byteslice(@descriptor + size - 4, 4).unpack1("V")
          dx_count = spacing_count(chars, dx, options)
          @cursor += 52
          buffer(string, chars * @width, @width, string.zero? && chars.zero?)
          buffer(dx, dx_count * 4, 4, dx.zero?)
          @descriptor += size
        end

        def rectangle(options, has_rect)
          with_rect = options.nobits?(0x100)
          size = with_rect ? 40 : 24
          reject! unless has_rect == (with_rect ? 1 : 0) && @descriptor + size <= @raw.bytesize

          bytes = with_rect ? @raw.byteslice(@descriptor + 20, 16) : "\0".b * 16
          reject! unless @payload.byteslice(@cursor + 16, 16) == bytes
          size
        end

        def spacing_count(chars, dx, options)
          text_count, has_dx, dx_count = @payload.byteslice(@cursor + 32, 20).unpack("Q<VQ<")
          reject! unless text_count == chars && has_dx == (dx.zero? ? 0 : 1)

          multiplier = options.anybits?(0x2000) ? 2 : 1
          expected = dx.zero? ? 0 : chars * multiplier
          reject! unless dx_count == expected
          dx_count
        end

        def buffer(offset, length, alignment, absent)
          reject! unless length <= @payload.bytesize - @cursor
          unless absent
            reject! unless offset >= 40 && (offset % alignment).zero? && offset <= @raw.bytesize
            reject! unless length <= @raw.bytesize - offset
            reject! unless @payload.byteslice(@cursor, length) == @raw.byteslice(offset, length)

            @spans << [offset, offset + length]
          end
          @cursor += length
        end

        def reject!
          PolyTextFields.reject!
        end
      end
    end
  end
end
