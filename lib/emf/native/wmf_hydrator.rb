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
        @errors = []
        header = hydrate_header
        records = hydrate_records
        recovered = Wmf::Evidence.reference_recovery(@input, @errors)
        Wmf::Binary.validate_objects(records, header.number_of_objects, recovered: recovered) do |record, message|
          fail_record(record.offset, record.type_id, message)
        end
        Model::Metafile.new(format: :wmf, header: header, records: records,
                            errors: Wmf::Evidence.ordered(@errors + Wmf::Evidence.drift_errors(@input)),
                            trailing: @input.byteslice(@limit..).to_s)
      end

      private

      def hydrate_header
        type, size, version, words, objects, maximum, members, placeable, eof, reserved = @snapshot.header
        validate_header(type, size, version, placeable, eof, reserved)
        @start = placeable == 1 ? 22 : 0
        # The record stream ends after the first EOF record, whatever its length or the declared Size (both are
        # recovered); the core keeps reading past an EOF it does not accept as final, so the stream is cut here.
        @records = framed_records

        placeable_header = hydrate_placeable(type) if placeable == 1
        raise_framing_error if @records.empty?
        @limit = @records.last.fetch(:offset) + @records.last.fetch(:length)

        Model::Wmf::Header.new(type: type, version: version, size_words: words, number_of_objects: objects,
                               max_record_words: maximum, number_of_members: members, placeable: placeable_header)
      end

      def validate_header(type, size, version, placeable, eof, reserved)
        valid = [1, 2].include?(type) && size == 9 && [0x100, 0x300].include?(version) &&
                [0, 1].include?(placeable) && [0, 1].include?(eof) && reserved.zero?
        raise FormatError, "invalid native WMF header" unless valid
        raise FormatError, "invalid native WMF source length" unless @snapshot.source_length == @input.bytesize
        raise FormatError, "WMF input too large" if @input.bytesize > Wmf::Binary::MAX_INPUT_BYTES
      end

      # The snapshot's records up to and including the first EOF record; empty when the core found none.
      def framed_records
        index = @snapshot.records.index { |record| record.fetch(:type).zero? }
        index ? @snapshot.records.first(index + 1) : []
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
        raise FormatError, "invalid native WMF placeable header" unless reserved.zero? && (type != 2 || handle.zero?)

        @errors << Wmf::Evidence.recovered_error(203, @input, nil) unless checksum == Wmf::Binary.checksum(@input.byteslice(0, 20))

        Model::Wmf::PlaceableHeader.new(handle: handle, left: left, top: top, right: right, bottom: bottom,
                                        inch: inch, checksum: checksum)
      end

      def hydrate_records
        if @records.length > Wmf::Binary::MAX_RECORDS
          raise ResourceLimitError.new(resource: :record_count, limit: Wmf::Binary::MAX_RECORDS,
                                       actual: Wmf::Binary::MAX_RECORDS + 1)
        end

        position = @start + 18
        records = @records.each_with_index.map do |record, index|
          length = record.fetch(:length)
          offset = record.fetch(:offset)
          validate_span(record, index, position)
          position += length
          hydrate_record(record, @input.byteslice(offset, length)).declare_size(length / 2)
        end
        unless position == @limit && records.last.is_a?(Model::Wmf::Records::Eof) && records.one?(Model::Wmf::Records::Eof)
          raise FormatError, "WMF requires one final EOF record"
        end

        records
      end

      # A recoverable shape is decoded by the Ruby contract itself (Wmf::Recovery) on the record's own bytes, so both
      # backends build the same record and error; every other record comes from the native typed fields.
      def hydrate_record(record, raw)
        recovered, reason = Wmf::Recovery.record(raw, record.fetch(:type), record.fetch(:offset))
        return WmfFields.new(record, raw).call unless reason

        @errors << Wmf::Evidence.recovered_error(reason, @input, record.fetch(:offset), record.fetch(:type))
        recovered
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
