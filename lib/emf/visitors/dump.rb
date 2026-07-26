# frozen_string_literal: true

module Emf
  module Visitors
    # Human-readable record-by-record dump. Used by `emf dump` (TODO 19)
    # and as a debugging tool.
    class Dump < Emf::Model::Visitor
      def initialize
        @lines = []
      end

      attr_reader :lines

      def to_s
        @lines.join("\n")
      end

      def visit(record)
        record.accept(self)
        self
      end

      def visit_all(metafile)
        @lines << format("Metafile format=%s records=%d errors=%d",
                         metafile.format, metafile.records.length, metafile.errors.length)
        header = metafile.header
        @lines << "  Header: #{header.class}" if header
        metafile.each { |record| record.accept(self) }
        metafile.errors.each { |e| @lines << "  Error: #{e.message}" }
        self
      end

      def visit_emr_wire_record(adapter)
        wire = adapter.wire
        @lines << "  rec[#{adapter.offset}] type_id=#{adapter.type_id} #{wire.class.name&.split('::')&.last}"
      end

      def method_missing(name, *args)
        return super unless name.to_s.start_with?("visit_")

        record = args.first
        return unless record

        type_id = begin
          record.type_id
        rescue StandardError
          nil
        end
        @lines << format("  rec: %s type_id=%s", record.class.name&.split("::")&.last, type_id)
      end

      def respond_to_missing?(name, _include_private = false)
        name.to_s.start_with?("visit_") || super
      end
    end
  end
end
