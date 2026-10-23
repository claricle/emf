# frozen_string_literal: true

require_relative "wmf_fields"
require_relative "wmf_snapshot"
require_relative "wmf_rejection"

module Emf
  module Native
    class WmfHydrator
      # Native parsing is authoritative for accepted input. A rejection, from the core or the hydrator, is reported
      # with the native first-rejection detail mapped to the contract's error; when the contract would accept the
      # input the native rejection is raised as is.
      def self.parse(loader, input)
        loader.wmf_document(input) do |document|
          new(WmfSnapshot.new(loader.wmf_snapshot(document)), input).call
        end
      rescue Emf::Error => e
        found = WmfRejection.read(loader.wmf_rejection(input, Wmf::Binary::MAX_INPUT_BYTES, Wmf::Binary::MAX_RECORDS))
        raise WmfRejection.error(found, input) if found

        raise e
      end

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
        raise FormatError, "invalid native WMF declared size" unless @limit <= @input.bytesize

        placeable_header = hydrate_placeable(type) if placeable == 1
        raise_framing_error unless eof_present?
        raise FormatError, "invalid native WMF declared size" unless @input.byteslice(@limit..) == @snapshot.trailing

        Model::Wmf::Header.new(type: type, version: version, size_words: words, number_of_objects: objects,
                               max_record_words: maximum, number_of_members: members, placeable: placeable_header)
      end

      def validate_header(type, size, version, words, placeable, eof, reserved)
        valid = [1, 2].include?(type) && size == 9 && [0x100, 0x300].include?(version) &&
                [0, 1].include?(placeable) && [0, 1].include?(eof) && reserved.zero? && words >= 9
        raise FormatError, "invalid native WMF header" unless valid
        raise FormatError, "invalid native WMF source length" unless @snapshot.source_length == @input.bytesize
        raise FormatError, "WMF input too large" if @input.bytesize > Wmf::Binary::MAX_INPUT_BYTES
      end

      def eof_present?
        @snapshot.header.fetch(8) == 1
      end

      # Core diagnostics 6-10 are record framing failures; Ruby raises ParseError for them.
      FRAMING_DIAGNOSTICS = {
        6 => "invalid record length", 7 => "truncated record", 8 => "invalid EOF record",
        9 => "missing EOF record", 10 => "malformed record payload"
      }.freeze
      private_constant :FRAMING_DIAGNOSTICS

      def raise_framing_error
        kind, has_function, function, _detail, offset = @snapshot.diagnostics.find { |entry| FRAMING_DIAGNOSTICS.key?(entry.first) }
        raise FormatError, "invalid native WMF header" unless kind

        raise ParseError.new(offset: offset, record_code: has_function == 1 ? function : nil,
                             message: "WMF #{FRAMING_DIAGNOSTICS.fetch(kind)} at offset #{offset}")
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
        if @snapshot.records.length > Wmf::Binary::MAX_RECORDS
          raise ResourceLimitError.new(resource: :record_count, limit: Wmf::Binary::MAX_RECORDS,
                                       actual: Wmf::Binary::MAX_RECORDS + 1)
        end

        position = @start + 18
        records = @snapshot.records.each_with_index.map do |record, index|
          length = record.fetch(:length)
          offset = record.fetch(:offset)
          validate_span(record, index, position)
          position += length
          WmfFields.new(record, @input.byteslice(offset, length)).call.declare_size(length / 2)
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
