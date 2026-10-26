# frozen_string_literal: true

module Emf
  module Native
    # Snapshot recovery kinds are provenance, independently of public error text.
    class DiagnosticContract
      def initialize(snapshot, input)
        @snapshot = snapshot
        @input = input
      end

      def call(metafile)
        return metafile if @snapshot.diagnostics.empty?

        offsets = @snapshot.table.each_slice(5).map { |entry| entry[1] }
        diagnostics = @snapshot.diagnostics.flat_map do |kind, has_type, type, _reserved, offset|
          index = offsets.bsearch_index { |candidate| candidate >= offset } || offsets.length
          code = has_type == 1 ? type : @input.unpack1("V", offset: offset) || 0
          if kind == Diagnostics::INVALID_PAYLOAD
            recovered_diagnostics(offset, index + 1, code)
          else
            [Model::Diagnostic.new(record_index: index + 1, record_code: code, byte_offset: offset, disposition: :skipped)]
          end
        end
        metafile.with_diagnostics(diagnostics.sort_by(&:byte_offset))
      end

      private

      def recovered_diagnostics(offset, index, code)
        return [] if Hydrator::OPAQUE_BODY_TYPES.include?(code)

        diagnostics = []
        Emr::Parser.read_record_at(@input, offset, [], diagnostics: diagnostics, record_index: index)
        diagnostics
      end
    end
  end
end
