# frozen_string_literal: true

module Emf
  module Model
    class Visitor
      @visit_methods = {}

      class << self
        # Record classes call this to declare a visit method name.
        # The base class installs a no-op default so subclasses can override
        # only what they need.
        def register_visit(name, record_class)
          @visit_methods[name] = record_class
          return if method_defined?(name)

          define_method(name) { |_| nil }
        end

        attr_reader :visit_methods

        # Walk every record in the metafile (and a nested EMF+ sub-stream if any),
        # dispatching to the matching visit_* method.
        def visit_all(visitor, metafile)
          metafile.each { |record| record.accept(visitor) }
          nested = metafile.emf_plus
          visit_all(visitor, nested) if nested.is_a?(Emf::Model::Metafile)
          visitor
        end
      end

      def visit(record)
        record.accept(self)
        self
      end

      def visit_all(metafile)
        self.class.visit_all(self, metafile)
        self
      end
    end
  end
end
