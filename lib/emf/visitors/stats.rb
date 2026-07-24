# frozen_string_literal: true

module Emf
  module Visitors
    class Stats < Emf::Model::Visitor
      def initialize
        @counts = Hash.new(0)
      end

      attr_reader :counts

      def histogram
        @counts.sort.to_h
      end

      def to_s
        histogram.map { |k, v| "#{v.to_s.rjust(6)}  #{k}" }.join("\n")
      end

      def method_missing(name, *args)
        return super unless name.to_s.start_with?("visit_")

        record = args.first
        @counts[record.class.name] += 1 if record
      end

      def respond_to_missing?(name, _include_private = false)
        name.to_s.start_with?("visit_") || super
      end
    end
  end
end
