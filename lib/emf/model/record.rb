# frozen_string_literal: true

module Emf
  module Model
    class Record
      def type_id
        raise NotImplementedError, "subclass must return the integer record type code"
      end

      def accept(_visitor)
        raise NotImplementedError, "subclass must implement #accept(visitor)"
      end

      def inspect
        "#<#{self.class.name} type_id=#{type_id}>"
      end
    end
  end
end
