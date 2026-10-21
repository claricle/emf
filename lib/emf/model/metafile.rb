# frozen_string_literal: true

module Emf
  module Model
    class Metafile
      include Enumerable

      def initialize(format:, header:, records:, errors: [], emf_plus: nil, trailing: "", emf_plus_source: nil)
        @format = format
        @header = header
        @records = records.freeze
        @errors = errors.freeze
        @emf_plus = emf_plus
        @trailing = trailing.freeze
        @emf_plus_source = emf_plus_source
      end

      attr_reader :format, :header, :records, :errors, :emf_plus, :trailing

      def each(&block)
        return to_enum unless block

        @records.each(&block)
      end

      # Typed EMF+ view; nil unless this is an EMF+ metafile. Memoised because
      # the metafile is immutable; `reload: true` rebuilds it from the current comment bytes.
      # A backend may supply `emf_plus_source` (called with the metafile and `reload`);
      # a nil result falls back to the Ruby stream.
      def emf_plus_stream(reload: false)
        return unless format == :emf_plus

        @emf_plus_stream = nil if reload
        @emf_plus_stream ||= @emf_plus_source&.call(self, reload) || Emf::EmfPlus::Stream.from_metafile(self)
      end

      def errors?
        !@errors.empty?
      end

      def ok?
        @errors.empty?
      end
    end
  end
end
