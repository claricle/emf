# frozen_string_literal: true

module Emf
  module Visitors
    class Dump < Emf::Model::Visitor
      def initialize
        @lines = []
      end

      attr_reader :lines

      def to_s
        @lines.join("\n")
      end

      def method_missing(name, *args)
        return super unless name.to_s.start_with?("visit_")

        record = args.first
        return unless record

        @lines << "#{name} #{record.inspect}"
      end

      def respond_to_missing?(name, _include_private = false)
        name.to_s.start_with?("visit_") || super
      end
    end
  end
end
