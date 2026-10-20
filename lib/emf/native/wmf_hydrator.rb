# frozen_string_literal: true

require_relative "wmf_fields"

module Emf
  module Native
    class WmfHydrator
      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
      end

      def call
        header = hydrate_header
        records = hydrate_records(header)
        Wmf::Binary.validate_objects(records, header.number_of_objects) do |record, message|
          fail_record(record.offset, record.type_id, message)
        end
        Model::Metafile.new(format: :wmf, header: header, records: records, trailing: @snapshot.trailing)
      end

      private

      def hydrate_header
        type, size, version, words, objects, maximum, members, placeable, eof, reserved = @snapshot.header
        validate_header(type, size, version, words, placeable, eof, reserved)
        @start = placeable == 1 ? 22 : 0
        @limit = @start + (words * 2)
        unless @limit <= @input.bytesize && @input.byteslice(@limit..) == @snapshot.trailing
          raise FormatError, "invalid native WMF declared size"
        end

        placeable_header = hydrate_placeable(type) if placeable == 1
        Model::Wmf::Header.new(type: type, version: version, size_words: words, number_of_objects: objects,
                               max_record_words: maximum, number_of_members: members, placeable: placeable_header)
      end

      def validate_header(type, size, version, words, placeable, eof, reserved)
        valid = [1, 2].include?(type) && size == 9 && [0x100, 0x300].include?(version) &&
                [0, 1].include?(placeable) && eof == 1 && reserved.zero? && words >= 9
        raise FormatError, "invalid native WMF header" unless valid
        raise FormatError, "invalid native WMF source length" unless @snapshot.source_length == @input.bytesize
        raise FormatError, "WMF input too large" if @input.bytesize > Wmf::Binary::MAX_INPUT_BYTES
      end

      def hydrate_placeable(type)
        handle, left, top, right, bottom, inch, reserved, checksum = @snapshot.placeable
        unless reserved.zero? && checksum == Wmf::Binary.checksum(@input.byteslice(0, 20)) && (type != 2 || handle.zero?)
          raise FormatError, "invalid native WMF placeable header"
        end

        Model::Wmf::PlaceableHeader.new(handle: handle, left: left, top: top, right: right, bottom: bottom,
                                        inch: inch, checksum: checksum)
      end

      def hydrate_records(header)
        raise FormatError, "WMF record limit exceeded" if @snapshot.records.length > Wmf::Binary::MAX_RECORDS

        position = @start + 18
        records = @snapshot.records.each_with_index.map do |record, index|
          length = record.fetch(:length)
          offset = record.fetch(:offset)
          validate_span(record, index, position)
          position += length
          WmfFields.new(record, @input.byteslice(offset, length)).call
        end
        unless position == @limit && records.last.is_a?(Model::Wmf::Records::Eof) && records.one?(Model::Wmf::Records::Eof)
          raise FormatError, "WMF requires one final EOF record"
        end

        largest = @snapshot.records.map { |record| record.fetch(:length) / 2 }.max
        raise FormatError, "WMF MaxRecord does not match largest record" unless largest == header.max_record_words

        records
      end

      def validate_span(record, index, position)
        length = record.fetch(:length)
        offset = record.fetch(:offset)
        return if record.fetch(:index) == index && offset == position && length >= 6 && length.even? && length <= @limit - offset

        raise FormatError, "invalid native WMF record span"
      end

      def fail_record(offset, type, message)
        raise ParseError.new(offset: offset, record_code: type, message: "WMF #{message} at offset #{offset}")
      end
    end
  end
end
