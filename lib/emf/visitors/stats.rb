# frozen_string_literal: true

module Emf
  module Visitors
    # Produces a record-class histogram for a Metafile. Used by spec assertions
    # (TODO 16) and as a quick sanity-check dump via `emf stats` (TODO 19).
    #
    # The base Visitor auto-registers `visit_*` methods as no-ops. Stats
    # overrides the generic dispatch to tally every record by its class name.
    # Subclasses that override specific visit_* methods for richer behaviour
    # still get tallied here because the record's accept calls the visit_*
    # method, which (if not overridden) calls method_missing -> tally.
    class Stats < Emf::Model::Visitor
      def initialize
        @counts = Hash.new(0)
      end

      attr_reader :counts

      def histogram
        @counts.sort.to_h
      end

      def total
        @counts.values.sum
      end

      def to_s
        lines = ["Total: #{total}", ""]
        histogram.each { |klass, count| lines << format("%6d  %s", count, klass) }
        lines.join("\n")
      end

      def visit(record)
        record.accept(self)
        self
      end

      def visit_all(metafile)
        metafile.each { |record| record.accept(self) }
        self
      end

      # WireAdapter is the catch-all for unknown record types. Tally by the
      # underlying wire class so the histogram is informative.
      def visit_emr_wire_record(adapter)
        wire_class = adapter.wire.class.name&.split("::")&.last || "Raw"
        @counts["WireAdapter(#{wire_class})"] += 1
      end

      def method_missing(name, *args)
        return super unless name.to_s.start_with?("visit_")

        record = args.first
        @counts[record.class.name&.split("::")&.last || record.class.to_s] += 1 if record
      end

      def respond_to_missing?(name, _include_private = false)
        name.to_s.start_with?("visit_") || super
      end
    end
  end
end
