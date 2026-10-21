# frozen_string_literal: true

module Emf
  module Native
    # Diagnoses input the native WMF path rejected. The core reports recovering diagnostics without Ruby's header
    # ordering or per-codec wording, so the rejection's class, message, offset and record code come from the
    # contract's own phase functions, run in the contract's order. This never produces a document: it either raises
    # the contract's error or reports that the contract accepts the input, in which case the native rejection stands.
    module WmfDiagnosis
      module_function

      def call(bytes)
        raise FormatError, "WMF input too large" if bytes.bytesize > Wmf::Binary::MAX_INPUT_BYTES

        placeable, start = Wmf::Parser.read_placeable(bytes)
        header = Wmf::Parser.read_header(bytes, start, placeable)
        limit = start + (header.size_words * 2)
        records = Wmf::Parser.read_records(bytes, start + Wmf::Binary::HEADER_BYTES, limit)
        Wmf::Binary.validate_objects(records, header.number_of_objects) do |record, message|
          raise ParseError.new(offset: record.offset, record_code: record.type_id,
                               message: "WMF #{message} at offset #{record.offset}")
        end
        largest = records.map { |record| Wmf::Parser.record_size(record) }.max
        raise FormatError, "WMF MaxRecord does not match largest record" unless header.max_record_words == largest
      end
    end
  end
end
