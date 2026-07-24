# frozen_string_literal: true

module Emf
  module Model
    class Metafile
      include Enumerable

      def initialize(format:, header:, records:, errors: [], emf_plus: nil, trailing: "")
        @format = format
        @header = header
        @records = records.freeze
        @errors = errors.freeze
        @emf_plus = emf_plus
        @trailing = trailing.freeze
      end

      attr_reader :format, :header, :records, :errors, :emf_plus, :trailing

      def each(&block)
        return to_enum unless block

        @records.each(&block)
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
