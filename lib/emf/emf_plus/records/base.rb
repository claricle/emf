# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      # A framed record whose body is read through a BinData class (BODY in the
      # subclass). Bytes after the body (padding, unknown trailing data) are
      # kept in `trailing`, so an unedited record re-encodes to its frame bytes.
      class Base
        attr_reader :type, :flags, :size, :data_size, :offset, :comment_index, :body, :trailing

        def initialize(frame)
          @type = frame.type
          @flags = frame.flags
          @size = frame.size
          @data_size = frame.data_size
          @offset = frame.offset
          @comment_index = frame.comment_index
          @body = read_body(frame)
          @trailing = frame.data.byteslice(@body.num_bytes..).freeze
        end

        def to_binary
          [type, flags, size, data_size].pack("vvVV") + body.to_binary_s + trailing
        end

        # Returns a new record with the given edits applied; the receiver is
        # unchanged. Keys are:
        #   flags:        the raw Record Flags value;
        #   flag fields:  the names in #flag_fields (compressed:, emf_object_id:,
        #                 combine_mode: ...). Booleans set or clear a bit, integers
        #                 fill a bit range; every other flag bit is kept;
        #   body fields:  any BinData field of the body. Length fields and
        #                 their arrays are independent, so a variable-length
        #                 edit sets both (item_count: 3, rect_data: {...}).
        # Size and DataSize are recomputed. Trailing bytes beyond the original
        # DataSize are alignment padding and are dropped (the new Size re-pads);
        # trailing bytes inside it are unknown data, kept after the body and
        # counted in DataSize.
        # Changing a flag that selects the body layout (compressed, relative)
        # keeps the other fields; array elements of the newly selected layout
        # start zeroed unless the same call supplies them.
        def with(**edits)
          new_flags = edited_flags(edits)
          new_body = edited_body(new_flags, edits)
          self.class.new(edited_frame(new_flags, new_body))
        end

        # Flag-backed attributes editable through #with, as { name => mask }.
        # Record families and mixins extend it with `super.merge(...)`.
        def flag_fields = {}

        private

        def edited_flags(edits)
          flag_edits = edits.slice(*flag_fields.keys)
          flag_edits.reduce(edits.fetch(:flags, flags)) do |bits, (name, value)|
            encode_flag(bits, name, flag_fields.fetch(name), value)
          end
        end

        def encode_flag(bits, name, mask, value)
          shift = (mask & -mask).bit_length - 1
          number = { true => 1, false => 0 }.fetch(value, value)
          unless number.is_a?(Integer) && number.between?(0, mask >> shift)
            raise ArgumentError, "#{name} must fit #{(mask >> shift).bit_length} bit(s), got #{value.inspect}"
          end

          (bits & ~mask) | (number << shift)
        end

        def edited_body(new_flags, edits)
          fields = edits.except(:flags, *flag_fields.keys)
          unknown = fields.keys - body.field_names
          raise ArgumentError, "unknown field(s) #{unknown.join(', ')} for #{self.class.name}" unless unknown.empty?

          self.class::BODY.new(data_size: data_size, flags: new_flags).tap do |fresh|
            fresh.assign(deep_merge(body.snapshot, fields))
          end
        end

        # BinData#assign(hash) clears every field it is not given, so edits
        # are folded into the body's own snapshot and assigned once.
        def deep_merge(base, edit)
          return edit unless base.is_a?(Hash) && edit.is_a?(Hash)

          base.merge(edit) { |_name, old, new| deep_merge(old, new) }
        end

        def edited_frame(new_flags, new_body)
          kept = trailing.byteslice(0, data_size - body.num_bytes)
          Frame.new(type: type, flags: new_flags, size: Frame::HEADER_BYTES, data_size: 0, data: "",
                    offset: offset, comment_index: comment_index).with_data(new_body.to_binary_s + kept)
        end

        def read_body(frame)
          self.class::BODY.new(data_size: data_size, flags: flags).read(frame.data.byteslice(0, data_size))
        rescue IOError, BinData::ValidityError => e
          raise ParseError.new(offset: offset, record_code: type,
                               message: "malformed #{self.class.name.split('::').last} body at offset #{offset}: #{e.message}")
        end
      end
    end
  end
end
