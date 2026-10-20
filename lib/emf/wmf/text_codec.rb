# frozen_string_literal: true

module Emf
  module Wmf
    module TextCodec
      module_function

      def decode(raw, function, offset, &)
        extended = function & 0xFF == 0x32
        minimum = extended ? 14 : 12
        yield("truncated text record") if raw.bytesize < minimum
        if extended
          y, x, count, options = raw.byteslice(6, 8).unpack("s<3v")
          start = 14
          if options.anybits?(6)
            yield("truncated text rectangle") if raw.bytesize < start + 8
            rectangle = Model::Wmf::Records::TextRectangle.new(**%i[left top right bottom].zip(
              raw.byteslice(start, 8).unpack("s<4")
            ).to_h)
            start += 8
          end
        else
          count = raw.byteslice(6, 2).unpack1("s<")
          start = 8
        end
        yield("negative text length") if count.negative?
        finish = start + count + (count % 2)
        yield("truncated text string") if raw.bytesize < finish + (extended ? 0 : 4)
        fields = { text: raw.byteslice(start, count), padding: raw.byteslice(start + count, count % 2),
                   type_id: function, offset: offset }
        return decode_extended(raw, finish, count, fields.merge(x: x, y: y, options: options, rectangle: rectangle), &) if extended

        fields[:padding] = raw.byteslice(start + count, raw.bytesize - 4 - start - count)
        y, x = raw.byteslice(-4, 4).unpack("s<2")
        Model::Wmf::Records::TextOut.new(**fields, x: x, y: y)
      end

      def decode_extended(raw, start, count, fields)
        remaining = raw.bytesize - start
        if remaining.positive? && count.positive?
          yield "truncated text spacing array" if remaining < count * 2
          dx = raw.byteslice(start, count * 2).unpack("s<*")
          start += count * 2
        end
        Model::Wmf::Records::ExtTextOut.new(**fields, dx: dx, suffix: raw.byteslice(start..))
      end

      def encode(record)
        extended = record.instance_of?(Model::Wmf::Records::ExtTextOut)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF text RecordFunction mismatch" unless function & 0xFF == (extended ? 0x32 : 0x21)

        raise SerializeError, "WMF text must be a byte string" unless record.text.is_a?(String)

        count = Binary.integer(record.text.bytesize, 0..0x7FFF, "StringLength")
        text = record.text.b
        x = Binary.int16(record.x, "X")
        y = Binary.int16(record.y, "Y")
        padding = byte_string(record.padding, "text padding")
        padding = aligned_padding(padding, count, extended)
        string = text + padding

        payload = if extended
                    encode_extended(record, count, y, x, string)
                  else
                    [count].pack("s<") + string + [y, x].pack("s<2")
                  end
        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def encode_extended(record, count, y, x, string)
        options = Binary.uint16(record.options, "fwOpts")
        rectangle = encode_rectangle(record.rectangle, options)
        suffix = byte_string(record.suffix, "text suffix")
        raise SerializeError, "WMF text suffix must be word aligned" if suffix.bytesize.odd?

        spacing = "".b
        unless record.dx.nil?
          raise SerializeError, "WMF text spacing count mismatch" unless record.dx.is_a?(Array) && record.dx.length == count

          spacing = record.dx.map { |value| Binary.int16(value, "Dx") }.pack("s<*")
        end
        raise SerializeError, "WMF text suffix requires a complete spacing array" if count.positive? && record.dx.nil? && !suffix.empty?

        [y, x, count, options].pack("s<3v") + rectangle + string + spacing + suffix
      end

      def aligned_padding(padding, count, extended)
        raise SerializeError, "WMF extended text padding must contain at most one byte" if extended && padding.bytesize > 1

        return "".b if count.even? && padding.bytesize <= 1
        return padding.empty? ? "\x00".b : padding if count.odd? && padding.bytesize <= 1
        raise SerializeError, "WMF text padding alignment mismatch" unless padding.bytesize % 2 == count % 2

        padding
      end

      def encode_rectangle(rectangle, options)
        unless options.anybits?(6)
          raise SerializeError, "WMF text rectangle requires clipping or opaque options" unless rectangle.nil?

          return "".b
        end
        raise SerializeError, "WMF text options require a rectangle" unless rectangle.is_a?(Model::Wmf::Records::TextRectangle)

        %i[left top right bottom].map { |field| Binary.int16(rectangle.public_send(field), field) }.pack("s<4")
      end

      def byte_string(value, name)
        raise SerializeError, "WMF #{name} must be a byte string" unless value.is_a?(String)

        value.b
      end

      def byte_size(record)
        size = record.text.bytesize + record.padding.bytesize
        return 12 + size unless record.is_a?(Model::Wmf::Records::ExtTextOut)

        14 + size + (record.rectangle ? 8 : 0) + (record.dx ? record.dx.length * 2 : 0) + record.suffix.bytesize
      end
    end
  end
end
